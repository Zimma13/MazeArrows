//
//  LevelBaker — offline campaign generator.
//
//  Compiles together with the app's Models/Logic sources (see bake.sh) and
//  writes a fresh levels.json: 200 levels on a smooth difficulty curve, all
//  solvable by construction, with special piece kinds introduced along the
//  way. Deterministic: same tool version → same catalog.
//

import Foundation

// MARK: - deterministic rng (duplicated from DailyPuzzleProvider — the app
// file is @MainActor-entangled with LevelLoader, not worth importing here)

struct BakerRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0xDEADBEEFCAFEBABE }
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}

func bakerHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

// MARK: - difficulty curve

let totalLevels = 240
/// Levels 1...mainCurveLevels ramp smoothly; everything past that is the
/// expert chapter which pushes the knobs beyond the hard ceiling.
let mainCurveLevels = 200

struct CurvePoint {
    let config: DifficultyConfig
    let targetDepth: Int
}

func curve(at index: Int) -> CurvePoint {
    let t = min(1.2, Double(index - 1) / Double(mainCurveLevels - 1))
    func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }

    let difficulty: Difficulty
    switch index {
    case ...60: difficulty = .easy
    case ...130: difficulty = .medium
    case ...200: difficulty = .hard
    default: difficulty = .expert
    }
    let lives: Int
    switch difficulty {
    case .easy: lives = 5
    case .medium: lives = 4
    case .hard, .expert: lives = 3
    }

    // Level 1 starts where the old campaign ENDED (~25 arrows on 12×16);
    // by level 240 the board is a dense ~29×40 tangle in the style of the
    // reference puzzles: long snakes with many turns, 140+ arrows.
    let config = DifficultyConfig(
        difficulty: difficulty,
        width: Int(lerp(12, 26).rounded()),
        height: Int(lerp(16, 36).rounded()),
        snakeMinLength: 4,
        snakeMaxLength: Int(lerp(10, 13).rounded()),
        straightBias: lerp(0.60, 0.40),
        chainBias: lerp(0.70, 0.98),
        // Free-at-start arrows scale with the perimeter — on big tangles the
        // challenge is FINDING them, so the cap grows with the board.
        maxInitialMovable: max(3, Int(lerp(4, 12).rounded())),
        minParallelDepth: 1, // gate handled below with relaxation
        lives: lives
    )
    return CurvePoint(config: config, targetDepth: Int(lerp(8, 17).rounded()))
}

// MARK: - base generation with relaxing depth gate

func generateBase(index: Int, rng: inout BakerRNG) -> Level? {
    let point = curve(at: index)
    let cfg = point.config
    var mask = Set<GridPoint>()
    for y in 0..<cfg.height {
        for x in 0..<cfg.width {
            mask.insert(GridPoint(x: x, y: y))
        }
    }

    for attempt in 0..<4000 {
        // Relax the gates as attempts pile up: depth bar drops every 150
        // misses, the initial-movable cap grows every 800.
        let requiredDepth = max(2, point.targetDepth - attempt / 150)
        let movableCap = cfg.maxInitialMovable + attempt / 800
        guard let pieces = SnakeFillGenerator.makePieces(
            mask: mask,
            boardWidth: cfg.width,
            boardHeight: cfg.height,
            config: cfg.snakeFill,
            idPrefix: "s\(index)",
            rng: &rng
        ) else { continue }

        let board = Board(width: cfg.width, height: cfg.height, pieces: pieces)
        let metrics = LevelMetrics.evaluate(board: board)
        guard metrics.initialMovable >= 1,
              metrics.initialMovable <= movableCap,
              metrics.parallelDepth >= requiredDepth,
              metrics.dullRatio <= 0.14 + Double(attempt) * 0.0001,
              LevelSolver.solve(board: board) != nil else { continue }

        return Level(
            id: "story_\(index)",
            index: index,
            difficulty: cfg.difficulty,
            width: cfg.width,
            height: cfg.height,
            lives: cfg.lives,
            pieces: pieces,
            threeStarMaxMistakes: 0,
            twoStarMaxMistakes: max(1, pieces.count / 5),
            name: nil
        )
    }
    return nil
}

// MARK: - special piece kinds along the curve

/// Applies a kind mutation and keeps it only if the level stays solvable.
func withKinds(level: Level, index: Int, rng: inout BakerRNG) -> Level {
    var pieces = level.pieces

    func rebuildSolvable(_ candidate: [ArrowPiece]) -> Bool {
        let board = Board(width: level.width, height: level.height, pieces: candidate)
        return LevelSolver.solve(board: board) != nil
    }

    // Fragile — cracks on a failed tap; pure risk, no solvability impact.
    // Counts scale with board population so big boards feel them too.
    if index >= 30 {
        let count = min(8, max(1 + (index - 30) / 40, pieces.count / 14))
        let indices = pieces.indices.shuffled(using: &rng).prefix(count)
        for i in indices { pieces[i].kind = .fragile }
    }

    // Frozen — unlocks after N removals; must be re-verified.
    if index >= 70 {
        let count = min(6, max(1 + (index - 70) / 60, pieces.count / 22))
        for _ in 0..<20 {
            var candidate = pieces
            let standardIndices = candidate.indices.filter { candidate[$0].kind == .standard }
            guard standardIndices.count >= count else { break }
            for i in standardIndices.shuffled(using: &rng).prefix(count) {
                candidate[i].kind = .frozen
                candidate[i].frozenUnlockNeighbors = Int.random(in: 2...4, using: &rng)
            }
            if rebuildSolvable(candidate) {
                pieces = candidate
                break
            }
        }
    }

    // Lock + key pair — the lock can't fly until its key has left.
    if index >= 110 && index % 3 == 0 {
        for _ in 0..<20 {
            var candidate = pieces
            let standardIndices = candidate.indices.filter { candidate[$0].kind == .standard }
            guard standardIndices.count >= 2 else { break }
            let picks = standardIndices.shuffled(using: &rng)
            candidate[picks[0]].kind = .lockedKey
            candidate[picks[0]].colorGroup = 1
            candidate[picks[1]].kind = .lockedLock
            candidate[picks[1]].colorGroup = 1
            if rebuildSolvable(candidate) {
                pieces = candidate
                break
            }
        }
    }

    return Level(
        id: level.id,
        index: level.index,
        difficulty: level.difficulty,
        width: level.width,
        height: level.height,
        lives: level.lives,
        pieces: pieces,
        threeStarMaxMistakes: level.threeStarMaxMistakes,
        twoStarMaxMistakes: level.twoStarMaxMistakes,
        name: level.name
    )
}

// MARK: - main

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "levels.json"

var catalog: [Level] = []
var failures: [Int] = []
let started = Date()

for index in 1...totalLevels {
    var rng = BakerRNG(seed: bakerHash("bake_v2_level_\(index)"))
    guard let base = generateBase(index: index, rng: &rng) else {
        failures.append(index)
        continue
    }
    let level = withKinds(level: base, index: index, rng: &rng)
    if let err = LevelValidator.validateLevel(level, requireSolvable: true) {
        print("level \(index): VALIDATION FAILED — \(err.description)")
        failures.append(index)
        continue
    }
    catalog.append(level)

    if index % 25 == 0 || index == 1 {
        let m = LevelMetrics.evaluate(board: level.makeBoard())
        let kinds = Dictionary(grouping: level.pieces, by: { $0.kind.rawValue })
            .map { "\($0.key):\($0.value.count)" }.sorted().joined(separator: " ")
        print(String(format: "level %3d  %2dx%-2d  pieces %2d  movable %d  depth %2d  [%@]",
                     index, level.width, level.height, m.pieceCount, m.initialMovable, m.parallelDepth, kinds))
    }
}

guard failures.isEmpty else {
    print("FAILED indices: \(failures) — not writing output")
    exit(1)
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let data = try encoder.encode(catalog)
try data.write(to: URL(fileURLWithPath: outputPath))
print(String(format: "baked %d levels in %.1fs → %@ (%.0f KB)",
             catalog.count, Date().timeIntervalSince(started), outputPath, Double(data.count) / 1024))
