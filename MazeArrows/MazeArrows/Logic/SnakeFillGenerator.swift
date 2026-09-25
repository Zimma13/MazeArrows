//
//  SnakeFillGenerator.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Dense level generation in the style of the reference puzzles: a region of
//  cells (the "mask") is partitioned into snake-shaped polyline pieces that
//  cover it COMPLETELY, then arrow directions are assigned by reverse peeling
//  — simulating a solve while building — so every generated level is solvable
//  by construction, no rejection lottery needed for solvability.
//
//  The mask can be the full board rectangle (campaign levels) or an arbitrary
//  silhouette (picture levels).
//

import Foundation

nonisolated struct SnakeFillConfig: Sendable {
    /// Snake length bounds in cells. Orphan merging may exceed `maxLength`
    /// by up to `minLength` cells.
    var minLength: Int
    var maxLength: Int
    /// 0...1 — probability of continuing straight when growing a snake.
    /// High values give long straight runs, low values give tight winding.
    var straightBias: Double
    /// 0...1 — how strongly direction assignment prefers pieces whose exit
    /// lane crosses already-peeled pieces. Higher values produce longer
    /// dependency chains (fewer initially-free arrows, deeper forced order).
    var chainBias: Double

    init(minLength: Int, maxLength: Int, straightBias: Double, chainBias: Double = 0.85) {
        self.minLength = max(2, minLength)
        self.maxLength = max(self.minLength, maxLength)
        self.straightBias = straightBias
        self.chainBias = chainBias
    }
}

/// Post-generation difficulty measurements used for quality gating.
nonisolated struct LevelMetrics: Sendable {
    let pieceCount: Int
    /// Arrows the player can remove on the very first move.
    let initialMovable: Int
    /// Rounds of "remove everything currently movable" until the board is
    /// empty — the depth of the forced dependency ordering.
    let parallelDepth: Int
    /// Blocked pieces whose nearest blocker is ≥ 3 cells away from the head:
    /// they LOOK free and bait mistakes.
    let trapCount: Int
    /// Fraction of "dull" pieces — 5+ cells with at most one turn. The
    /// reference puzzles read as tangled because long pieces wind; a board
    /// full of straight strips looks (and plays) too easy.
    let dullRatio: Double

    static func turnCount(of cells: [GridPoint]) -> Int {
        guard cells.count >= 3 else { return 0 }
        var turns = 0
        for i in 1..<(cells.count - 1) {
            let dx1 = cells[i].x - cells[i - 1].x
            let dy1 = cells[i].y - cells[i - 1].y
            let dx2 = cells[i + 1].x - cells[i].x
            let dy2 = cells[i + 1].y - cells[i].y
            if dx1 != dx2 || dy1 != dy2 { turns += 1 }
        }
        return turns
    }

    static func evaluate(board: Board) -> LevelMetrics {
        let count = board.pieces.count
        let movableNow = MoveValidator.availableMoves(board: board)

        var traps = 0
        let occupied = board.occupiedMap()
        for piece in board.pieces {
            var cell = piece.headCell
            var distance = 0
            var blockedFar = false
            while true {
                let next = cell.moved(piece.direction)
                if !board.isInside(next) { break }
                distance += 1
                if let id = occupied[next], id != piece.id {
                    blockedFar = distance >= 3
                    break
                }
                cell = next
            }
            if blockedFar { traps += 1 }
        }

        var depth = 0
        var sim = board
        while !sim.pieces.isEmpty {
            let movable = MoveValidator.availableMoves(board: sim)
            if movable.isEmpty { break }
            for piece in movable { sim.removePiece(id: piece.id) }
            depth += 1
        }

        let dull = board.pieces.filter { $0.cells.count >= 5 && turnCount(of: $0.cells) <= 1 }.count

        return LevelMetrics(
            pieceCount: count,
            initialMovable: movableNow.count,
            parallelDepth: depth,
            trapCount: traps,
            dullRatio: count > 0 ? Double(dull) / Double(count) : 0
        )
    }
}

nonisolated enum SnakeFillGenerator {

    /// Fills `mask` with oriented snake pieces. Returns nil when the random
    /// partition or the peeling got stuck — callers just retry (each attempt
    /// is cheap; typical success rate is well above 50%).
    static func makePieces<G: RandomNumberGenerator>(
        mask: Set<GridPoint>,
        boardWidth: Int,
        boardHeight: Int,
        config: SnakeFillConfig,
        idPrefix: String,
        rng: inout G
    ) -> [ArrowPiece]? {
        makePieces(
            zones: [mask],
            boardWidth: boardWidth,
            boardHeight: boardHeight,
            config: config,
            idPrefix: idPrefix,
            colorGroups: false,
            rng: &rng
        )
    }

    /// Multi-zone variant for picture levels: each zone (a color region of
    /// the source image) is partitioned into its own snakes so pieces never
    /// straddle a color boundary, then ALL pieces are oriented together on
    /// the shared board. With `colorGroups`, pieces carry their zone index
    /// as `colorGroup` so rendering can tint them per zone.
    static func makePieces<G: RandomNumberGenerator>(
        zones: [Set<GridPoint>],
        boardWidth: Int,
        boardHeight: Int,
        config: SnakeFillConfig,
        idPrefix: String,
        colorGroups: Bool,
        rng: inout G
    ) -> [ArrowPiece]? {
        var paths: [[GridPoint]] = []
        var zoneOfCell: [GridPoint: Int] = [:]
        for (zoneIndex, mask) in zones.enumerated() {
            guard !mask.isEmpty else { continue }
            guard mask.count >= config.minLength,
                  let zonePaths = partition(
                    mask: mask,
                    config: config,
                    rng: &rng
                  )
            else { return nil }
            paths.append(contentsOf: zonePaths)
            for cell in mask { zoneOfCell[cell] = zoneIndex }
        }
        guard !paths.isEmpty else { return nil }

        guard let oriented = orient(
            paths: paths,
            boardWidth: boardWidth,
            boardHeight: boardHeight,
            zoneOfCell: zoneOfCell,
            config: config,
            rng: &rng
        ) else { return nil }

        return oriented.enumerated().map { index, snake in
            ArrowPiece(
                id: "\(idPrefix)_\(index + 1)",
                cells: snake.cells,
                direction: snake.direction,
                kind: .standard,
                colorGroup: colorGroups ? zoneOfCell[snake.cells[0]] : nil
            )
        }
    }

    // MARK: - partition: mask → snakes

    private static let allDirections: [Direction] = [.up, .down, .left, .right]

    /// Flat-array view of the not-yet-consumed mask cells: O(1) membership
    /// and incrementally maintained free-neighbor counts, so the dead-end-
    /// first heuristics never rescan a Set in the hot path. Indices are
    /// local to the mask's bounding box.
    private struct FreeGrid {
        private let minX: Int
        private let minY: Int
        private let width: Int
        private let height: Int
        private var free: [Bool]
        private var neighborScore: [Int8]
        /// Compact list of free cells (swap-remove order, not meaningful).
        private(set) var freeCells: [GridPoint]
        private var positionOf: [Int32]

        var freeCount: Int { freeCells.count }

        init(mask: Set<GridPoint>) {
            var lowX = Int.max, lowY = Int.max, highX = Int.min, highY = Int.min
            for cell in mask {
                lowX = min(lowX, cell.x); highX = max(highX, cell.x)
                lowY = min(lowY, cell.y); highY = max(highY, cell.y)
            }
            minX = lowX
            minY = lowY
            width = max(0, highX - lowX + 1)
            height = max(0, highY - lowY + 1)
            free = [Bool](repeating: false, count: width * height)
            neighborScore = [Int8](repeating: 0, count: width * height)
            positionOf = [Int32](repeating: -1, count: width * height)
            freeCells = Array(mask)
            for (position, cell) in freeCells.enumerated() {
                let i = (cell.y - minY) * width + (cell.x - minX)
                free[i] = true
                positionOf[i] = Int32(position)
            }
            for cell in freeCells {
                var score: Int8 = 0
                if contains(GridPoint(x: cell.x + 1, y: cell.y)) { score += 1 }
                if contains(GridPoint(x: cell.x - 1, y: cell.y)) { score += 1 }
                if contains(GridPoint(x: cell.x, y: cell.y + 1)) { score += 1 }
                if contains(GridPoint(x: cell.x, y: cell.y - 1)) { score += 1 }
                neighborScore[(cell.y - minY) * width + (cell.x - minX)] = score
            }
        }

        private func index(_ cell: GridPoint) -> Int? {
            let x = cell.x - minX
            let y = cell.y - minY
            guard x >= 0, x < width, y >= 0, y < height else { return nil }
            return y * width + x
        }

        func contains(_ cell: GridPoint) -> Bool {
            guard let i = index(cell) else { return false }
            return free[i]
        }

        /// Free-neighbor count of a FREE cell (undefined for consumed cells).
        func score(of cell: GridPoint) -> Int {
            guard let i = index(cell) else { return 0 }
            return Int(neighborScore[i])
        }

        mutating func remove(_ cell: GridPoint) {
            guard let i = index(cell), free[i] else { return }
            free[i] = false
            let position = Int(positionOf[i])
            let lastCell = freeCells[freeCells.count - 1]
            freeCells[position] = lastCell
            positionOf[(lastCell.y - minY) * width + (lastCell.x - minX)] = Int32(position)
            freeCells.removeLast()
            positionOf[i] = -1
            for neighbor in [
                GridPoint(x: cell.x + 1, y: cell.y), GridPoint(x: cell.x - 1, y: cell.y),
                GridPoint(x: cell.x, y: cell.y + 1), GridPoint(x: cell.x, y: cell.y - 1),
            ] {
                if let n = index(neighbor) { neighborScore[n] -= 1 }
            }
        }
    }

    /// Splits the mask into simple polyline paths that cover every cell.
    /// Growth is dead-end-first (cells with few free neighbors are consumed
    /// early) which keeps stranded 1-cell orphans rare; the ones that do
    /// appear get merged into an adjacent path's endpoint.
    private static func partition<G: RandomNumberGenerator>(
        mask: Set<GridPoint>,
        config: SnakeFillConfig,
        rng: inout G
    ) -> [[GridPoint]]? {
        var free = FreeGrid(mask: mask)
        var paths: [[GridPoint]] = []

        while free.freeCount > 0 {
            // pickStart scans every remaining cell and sorts the best ties.
            let start = pickStart(from: free, rng: &rng)
            free.remove(start)
            var path = [start]

            while path.count < config.maxLength {
                if let next = pickNext(path: path, free: free, config: config, rng: &rng) {
                    path.append(next)
                    free.remove(next)
                } else {
                    // Head end is stuck — try continuing from the tail.
                    path.reverse()
                    if let next = pickNext(path: path, free: free, config: config, rng: &rng) {
                        path.append(next)
                        free.remove(next)
                    } else {
                        break
                    }
                }
            }
            paths.append(path)
        }

        return mergeOrphans(paths: paths, config: config)
    }

    /// Prefer starting where space is tightest — classic dead-end-first fill.
    private static func pickStart<G: RandomNumberGenerator>(
        from free: FreeGrid,
        rng: inout G
    ) -> GridPoint {
        var best: [GridPoint] = []
        var bestScore = Int.max
        for cell in free.freeCells {
            let score = free.score(of: cell)
            if score < bestScore {
                bestScore = score
                best = [cell]
            } else if score == bestScore {
                best.append(cell)
            }
        }
        // freeCells order is unstable (swap-remove); sort so the seeded rng
        // stays deterministic across runs.
        best.sort { ($0.y, $0.x) < ($1.y, $1.x) }
        return best.randomElement(using: &rng) ?? free.freeCells.first!
    }

    /// Number of trailing steps that continue in one straight line.
    private static func trailingRun(of path: [GridPoint]) -> Int {
        guard path.count >= 2 else { return 0 }
        let dx = path[path.count - 1].x - path[path.count - 2].x
        let dy = path[path.count - 1].y - path[path.count - 2].y
        var run = 1
        var i = path.count - 2
        while i >= 1,
              path[i].x - path[i - 1].x == dx,
              path[i].y - path[i - 1].y == dy {
            run += 1
            i -= 1
        }
        return run
    }

    private static func pickNext<G: RandomNumberGenerator>(
        path: [GridPoint],
        free: FreeGrid,
        config: SnakeFillConfig,
        rng: inout G
    ) -> GridPoint? {
        guard let end = path.last else { return nil }
        var candidates: [GridPoint] = []
        for dir in allDirections {
            let n = end.moved(dir)
            if free.contains(n) { candidates.append(n) }
        }
        guard !candidates.isEmpty else { return nil }

        if path.count >= 2 {
            let prev = path[path.count - 2]
            let straight = GridPoint(x: end.x * 2 - prev.x, y: end.y * 2 - prev.y)
            if candidates.contains(straight) {
                // Long straight runs are what make a board read as "easy" —
                // once a run reaches 3 cells, turn whenever a turn exists.
                if trailingRun(of: path) >= 3, candidates.count > 1 {
                    candidates.removeAll { $0 == straight }
                } else if Double.random(in: 0..<1, using: &rng) < config.straightBias {
                    return straight
                }
            }
        }

        // Among turns, prefer the tightest cell so it doesn't strand later.
        var best: [GridPoint] = []
        var bestScore = Int.max
        for candidate in candidates {
            let score = free.score(of: candidate)
            if score < bestScore {
                bestScore = score
                best = [candidate]
            } else if score == bestScore {
                best.append(candidate)
            }
        }
        best.sort { ($0.y, $0.x) < ($1.y, $1.x) }
        return best.randomElement(using: &rng)
    }

    /// Concatenates too-short paths onto an adjacent path's endpoint. Returns
    /// nil when an orphan has no endpoint-adjacent host — the caller retries
    /// the whole partition.
    private static func mergeOrphans(
        paths: [[GridPoint]],
        config: SnakeFillConfig
    ) -> [[GridPoint]]? {
        var result = paths.filter { $0.count >= config.minLength }
        var orphans = paths.filter { $0.count < config.minLength }
        let lengthCap = config.maxLength + config.minLength

        while let orphan = orphans.popLast() {
            var merged = false
            for index in result.indices where result[index].count + orphan.count <= lengthCap {
                if let combined = concatenated(result[index], orphan) {
                    result[index] = combined
                    merged = true
                    break
                }
            }
            if !merged {
                // Merge two orphans together.
                if let otherIndex = orphans.indices.first(where: { concatenated(orphans[$0], orphan) != nil }) {
                    let combined = concatenated(orphans[otherIndex], orphan)!
                    orphans.remove(at: otherIndex)
                    if combined.count >= config.minLength {
                        result.append(combined)
                    } else {
                        orphans.append(combined)
                    }
                    merged = true
                }
            }
            if !merged {
                // Last resort: split a host at an interior cell the orphan
                // touches — frequent on jagged photo-silhouette masks where
                // orphans sit against the middle of a snake.
                merged = attachBySplitting(
                    orphan: orphan,
                    into: &result,
                    config: config
                )
            }
            if !merged { return nil }
        }
        return result
    }

    /// Attaches `orphan` by splitting a host path at an interior cell the
    /// orphan touches: the host prefix (through the touch point) plus the
    /// orphan becomes one snake, the host remainder another. Both resulting
    /// snakes must stay at least `minLength` long.
    private static func attachBySplitting(
        orphan: [GridPoint],
        into paths: inout [[GridPoint]],
        config: SnakeFillConfig
    ) -> Bool {
        func adjacent(_ p: GridPoint, _ q: GridPoint) -> Bool {
            abs(p.x - q.x) + abs(p.y - q.y) == 1
        }
        guard let orphanFirst = orphan.first, let orphanLast = orphan.last else { return false }

        for hostIndex in paths.indices {
            let host = paths[hostIndex]
            for splitIndex in host.indices {
                let touch = host[splitIndex]
                let attached: [GridPoint]
                if adjacent(touch, orphanFirst) {
                    attached = orphan
                } else if adjacent(touch, orphanLast) {
                    attached = orphan.reversed()
                } else {
                    continue
                }
                let prefix = Array(host[0...splitIndex]) + attached
                let suffix = Array(host[(splitIndex + 1)...])
                guard prefix.count >= config.minLength,
                      suffix.isEmpty || suffix.count >= config.minLength
                else { continue }
                paths[hostIndex] = prefix
                if !suffix.isEmpty { paths.append(suffix) }
                return true
            }
        }
        return false
    }

    /// Joins two simple paths end-to-end if any endpoint pair is adjacent.
    private static func concatenated(_ a: [GridPoint], _ b: [GridPoint]) -> [GridPoint]? {
        func adjacent(_ p: GridPoint, _ q: GridPoint) -> Bool {
            abs(p.x - q.x) + abs(p.y - q.y) == 1
        }
        guard let aFirst = a.first, let aLast = a.last,
              let bFirst = b.first, let bLast = b.last else { return nil }
        if adjacent(aLast, bFirst) { return a + b }
        if adjacent(aLast, bLast) { return a + b.reversed() }
        if adjacent(aFirst, bFirst) { return a.reversed() + b }
        if adjacent(aFirst, bLast) { return b + a }
        return nil
    }

    // MARK: - orientation: reverse peeling

    private struct OrientedSnake {
        let cells: [GridPoint]
        let direction: Direction
    }

    private struct PeelCandidate {
        let pathIndex: Int
        let reversed: Bool
        let direction: Direction
        let dependencyScore: Int
    }

    private static func direction(from a: GridPoint, to b: GridPoint) -> Direction? {
        switch (b.x - a.x, b.y - a.y) {
        case (1, 0): return .right
        case (-1, 0): return .left
        case (0, 1): return .down
        case (0, -1): return .up
        default: return nil
        }
    }

    /// Assigns each path a head (one of its two endpoints) by simulating the
    /// solve: repeatedly pick a path that could fly out RIGHT NOW given the
    /// pieces still on the board, fix that orientation, remove it. The peel
    /// order is therefore a valid solution — the level is solvable by
    /// construction. Peeling prefers candidates whose exit lane crosses many
    /// already-peeled pieces, which turns into "this arrow was blocked until
    /// those flew out" — long dependency chains at play time.
    ///
    /// Dead ends are common at scale: the last few unpeeled snakes often
    /// block each other mutually (e.g. two long crossing snakes), and no
    /// peel ORDER can fix that — only a different cut can. So on a dead end
    /// the stuck region is simply RE-PARTITIONED into new snakes (per color
    /// zone) and peeling continues.
    private static func orient<G: RandomNumberGenerator>(
        paths initialPaths: [[GridPoint]],
        boardWidth: Int,
        boardHeight: Int,
        zoneOfCell: [GridPoint: Int],
        config: SnakeFillConfig,
        rng: inout G
    ) -> [OrientedSnake]? {
        // `active` mutates on repairs, so all bookkeeping is index-based
        // against it and rebuilt when it changes. Every peel round walks the
        // exit lane of every candidate, so occupancy lives in flat arrays
        // indexed by cell — no dictionary hashing in the hot loop.
        var active = initialPaths
        var occupied = [Int32](repeating: -1, count: boardWidth * boardHeight)
        for (index, path) in active.enumerated() {
            for cell in path { occupied[cell.y * boardWidth + cell.x] = Int32(index) }
        }
        var done: [OrientedSnake] = []
        var peeledOwner = [Int32](repeating: -1, count: boardWidth * boardHeight)
        // Dead ends grow with board size — large photo masks (500+ pieces)
        // need far more re-cuts than the campaign grids. Repairs only spend
        // when peeling is stuck, so a generous budget never slows down or
        // alters a run that would have succeeded anyway.
        let cellTotal = initialPaths.reduce(0) { $0 + $1.count }
        var repairsLeft = max(8, cellTotal / 20)

        // Distinct-owner counting without per-candidate Set allocations: one
        // stamp slot per peeled piece, a shared epoch marks "seen this lane".
        var ownerStamp: [Int32] = []
        var epoch: Int32 = 0

        func candidatesNow() -> [PeelCandidate] {
            var result: [PeelCandidate] = []
            for index in active.indices {
                let path = active[index]
                for reversed in [false, true] {
                    let head = reversed ? path[0] : path[path.count - 1]
                    let neck = reversed ? path[1] : path[path.count - 2]
                    guard let dir = direction(from: neck, to: head) else { continue }

                    // Exit lane from the head to the board edge must be clear
                    // of every piece still on the board — including this
                    // path's own body (the validator forbids self-crossed
                    // exit lanes).
                    var x = head.x + dir.dx
                    var y = head.y + dir.dy
                    var clear = true
                    var dependencyScore = 0
                    epoch += 1
                    while x >= 0, x < boardWidth, y >= 0, y < boardHeight {
                        let cell = y * boardWidth + x
                        if occupied[cell] >= 0 { clear = false; break }
                        let owner = Int(peeledOwner[cell])
                        if owner >= 0, ownerStamp[owner] != epoch {
                            ownerStamp[owner] = epoch
                            dependencyScore += 1
                        }
                        x += dir.dx
                        y += dir.dy
                    }
                    guard clear else { continue }
                    result.append(PeelCandidate(
                        pathIndex: index,
                        reversed: reversed,
                        direction: dir,
                        dependencyScore: dependencyScore
                    ))
                }
            }
            return result
        }

        /// Re-partitions the cells of all still-unpeeled snakes, zone by
        /// zone, giving the stuck region a fresh cut.
        func repairStuckRegion() -> Bool {
            guard repairsLeft > 0 else { return false }
            repairsLeft -= 1
            var cellsByZone: [Int: Set<GridPoint>] = [:]
            for path in active {
                for cell in path {
                    cellsByZone[zoneOfCell[cell] ?? 0, default: []].insert(cell)
                }
            }
            var newPaths: [[GridPoint]] = []
            for (_, zoneCells) in cellsByZone.sorted(by: { $0.key < $1.key }) {
                guard let zonePaths = partition(
                    mask: zoneCells,
                    config: config,
                    rng: &rng
                ) else {
                    return false
                }
                newPaths.append(contentsOf: zonePaths)
            }
            active = newPaths
            for i in occupied.indices { occupied[i] = -1 }
            for (index, path) in active.enumerated() {
                for cell in path { occupied[cell.y * boardWidth + cell.x] = Int32(index) }
            }
            return true
        }

        while !active.isEmpty {
            let candidates = candidatesNow()
            guard !candidates.isEmpty else {
                guard repairStuckRegion() else { return nil }
                continue
            }

            // Every zero-dependency pick becomes an arrow that is free at
            // level start, so pick among dependent candidates whenever any
            // exist; chainBias then decides how greedily we chase the
            // longest chains.
            let pick: PeelCandidate
            let dependent = candidates.filter { $0.dependencyScore > 0 }
            if !dependent.isEmpty {
                if Double.random(in: 0..<1, using: &rng) < config.chainBias {
                    let maxScore = dependent.map(\.dependencyScore).max() ?? 1
                    pick = dependent.filter { $0.dependencyScore == maxScore }.randomElement(using: &rng)!
                } else {
                    pick = dependent.randomElement(using: &rng)!
                }
            } else {
                pick = candidates.randomElement(using: &rng)!
            }

            let path = active[pick.pathIndex]
            let cells = pick.reversed ? Array(path.reversed()) : path
            done.append(OrientedSnake(cells: cells, direction: pick.direction))
            ownerStamp.append(-1)
            let owner = Int32(done.count - 1)
            for cell in path {
                let index = cell.y * boardWidth + cell.x
                occupied[index] = -1
                peeledOwner[index] = owner
            }
            // Swap-remove; fix the occupied indices of the path that moved.
            let lastIndex = active.count - 1
            if pick.pathIndex != lastIndex {
                active[pick.pathIndex] = active[lastIndex]
                for cell in active[pick.pathIndex] {
                    occupied[cell.y * boardWidth + cell.x] = Int32(pick.pathIndex)
                }
            }
            active.removeLast()
        }

        return done
    }
}
