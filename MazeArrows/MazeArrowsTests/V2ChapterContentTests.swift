import CryptoKit
import Foundation
import Testing
@testable import MazeArrows

/// These checks protect the authored ideas, not merely the existence of a solution.
/// The reference graph scans the complete head ray independently of MoveValidator.
struct V2ChapterContentTests {
    private func load(_ resource: String) throws -> [Level] {
        let url = try #require(Bundle.main.url(forResource: resource, withExtension: "json"))
        return try JSONDecoder().decode([Level].self, from: Data(contentsOf: url))
    }

    private func shortID(_ id: String) -> String {
        String(id.split(separator: "_", maxSplits: 1).last ?? Substring(id))
    }

    private func ray(_ piece: ArrowPiece, on board: Board) -> Set<GridPoint> {
        var result: Set<GridPoint> = []
        var cell = piece.headCell.moved(piece.direction)
        while board.isInside(cell) {
            result.insert(cell)
            cell = cell.moved(piece.direction)
        }
        return result
    }

    private func physicalPredecessors(_ piece: ArrowPiece, on board: Board) -> Set<String> {
        let lane = ray(piece, on: board)
        return Set(board.pieces.filter { other in
            other.id != piece.id && !lane.isDisjoint(with: other.cells)
        }.map(\.id))
    }

    private func gatesOnRay(_ piece: ArrowPiece, on board: Board) -> [Obstacle] {
        let lane = ray(piece, on: board)
        return board.obstacles.filter { lane.contains($0.cell) }
    }

    private func dependencies(_ board: Board, omittingGate: String? = nil) -> [String: Set<String>] {
        Dictionary(uniqueKeysWithValues: board.pieces.map { piece in
            let gateKeys = gatesOnRay(piece, on: board)
                .filter { $0.id != omittingGate }
                .compactMap(\.parameter)
            return (piece.id, physicalPredecessors(piece, on: board).union(gateKeys))
        })
    }

    private func board(_ level: Level, after names: [String]) throws -> Board {
        var board = level.makeBoard()
        for name in names {
            let piece = try #require(board.pieces.first { shortID($0.id) == name })
            try #require(MoveValidator.canFlyOut(piece: piece, board: board), "Illegal authored prefix: \(level.index) / \(name)")
            board.removePiece(id: piece.id)
        }
        return board
    }

    @Test func legacyDataIsByteForByteUnchangedAndV2IsASeparateAppendOnlyPackage() throws {
        let legacyURL = try #require(Bundle.main.url(forResource: "levels", withExtension: "json"))
        let legacyData = try Data(contentsOf: legacyURL)
        let digest = SHA256.hash(data: legacyData).map { String(format: "%02x", $0) }.joined()
        #expect(digest == "f781f36eb3a64e8e2e84c5fb3e693e83e0f1425cc37a801d63acd7a06fb223c9")

        let old = try JSONDecoder().decode([Level].self, from: legacyData)
        let new = try load("levels-v2")
        #expect(old.count == 240)
        #expect(old.allSatisfy { $0.rulesVersion == 1 })
        #expect(new.map(\.index) == Array(241...260))
        #expect(new.map(\.id) == (241...260).map { "story_\($0)" })
        #expect(Set(old.map(\.id)).isDisjoint(with: new.map(\.id)))
        for level in new {
            #expect(level.rulesVersion == 2)
            #expect(level.goal == .clearAll)
            #expect(level.lives == 4)
            #expect(level.stars(for: 0) == 3)
            #expect(level.stars(for: 1) == 2)
            #expect(level.stars(for: 2) == 1)
            #expect(level.pieces.allSatisfy { $0.kind == .standard || $0.kind == .lockedKey })
            #expect((1...4).contains(level.obstacles.count))
            #expect(level.obstacles.allSatisfy { $0.kind == .keyGate })
            #expect(LevelValidator.validateLevel(level, requireSolvable: true) == nil)
        }
    }

    @Test func everyCoreKeepsTheExactPhysicalAndGateDependenciesFromItsDesignBrief() throws {
        // Ordinary tails may follow these nodes, but may never become hidden
        // predecessors that destroy independence or make a gate decorative.
        let physical: [Int: [String: Set<String>]] = [
            241: ["KA": [], "X": [], "Y": ["X"]],
            242: ["KA": [], "X": [], "S": []],
            243: ["P": [], "KA": ["P"], "X": [], "Y": ["X"]],
            244: ["KA": [], "X": [], "Y": []],
            245: ["P": [], "KA": ["P"], "Q": [], "X": [], "Y": ["Q"]],
            246: ["KA": [], "X": [], "Y": ["X"], "S": [], "T": []],
            247: ["KA": [], "KB": [], "X": [], "Y": []],
            248: ["KA": [], "KB": [], "X": [], "Y": ["X"]],
            249: ["P": [], "KA": ["P"], "X": [], "Q": [], "R": ["Q"], "KB": ["R"], "Y": []],
            250: ["P": [], "KA": ["P"], "U": [], "KB": ["U"], "V": [], "X": []],
            251: ["P": [], "KA": ["P"], "X": [], "Y": []],
            252: ["P": [], "KA": ["P"], "Q": [], "KB": ["Q"], "X": []],
            253: ["P": [], "Q": [], "KA": ["P", "Q"], "X": [], "Y": []],
            254: ["KA": [], "U": [], "P": [], "KB": ["P"], "X": ["U"]],
            255: ["P": [], "KA": ["P"], "C": [], "KB": ["C"], "U": ["C"], "X": [], "Y": []],
            256: ["KA": [], "KB": [], "X": [], "U": ["X"], "Y": [], "V": ["Y"]],
            257: ["KA": [], "X": [], "P": [], "KB": ["P"], "Y": []],
            258: ["P": [], "KA": ["P"], "U": [], "V": [], "KB": ["U"], "X": [], "Y": [], "Z": ["V", "X"]],
            259: ["P": [], "KA": ["P"], "Q": [], "KB": ["Q"], "X": [], "Y": [], "Z": []],
            260: ["P": [], "Q": [], "KA": ["P", "Q"], "C": [], "U": [], "KB": ["C"], "X": [], "Y": [], "T": ["U", "X"]]
        ]
        let gates: [Int: [String: Set<String>]] = [
            241: ["X": ["ga1"]], 242: ["X": ["ga1"]], 243: ["X": ["ga1"]],
            244: ["X": ["ga1"], "Y": ["ga2"]], 245: ["X": ["ga1"], "Y": ["ga2"]],
            246: ["X": ["ga1"]], 247: ["X": ["ga1"], "Y": ["gb1"]],
            248: ["KB": ["ga1"], "X": ["gb1"]], 249: ["X": ["ga1"], "Y": ["gb1"]],
            250: ["U": ["ga1"], "V": ["ga2"], "X": ["gb1"]],
            251: ["X": ["ga1"], "Y": ["ga1"]], 252: ["X": ["ga1", "gb1"]],
            253: ["X": ["ga1"], "Y": ["ga2"]], 254: ["U": ["ga1"], "X": ["gb1"]],
            255: ["C": ["ga1"], "X": ["gb1"], "Y": ["gb2"]],
            256: ["X": ["ga1"], "Y": ["gb1"]], 257: ["X": ["ga1"], "Y": ["gb1"]],
            258: ["U": ["ga1"], "V": ["ga1"], "X": ["gb1"], "Y": ["gb2"]],
            259: ["X": ["ga1"], "Y": ["gb1"], "Z": ["ga2", "gb2"]],
            260: ["C": ["ga1"], "U": ["ga2"], "X": ["gb1"], "Y": ["gb2"]]
        ]
        for level in try load("levels-v2") {
            let board = level.makeBoard()
            for (name, expected) in try #require(physical[level.index]) {
                let piece = try #require(board.pieces.first { shortID($0.id) == name })
                let actual = Set(physicalPredecessors(piece, on: board).map(shortID))
                #expect(actual == expected, "Physical graph changed: \(level.index)/\(name)")
                let onRay = Set(gatesOnRay(piece, on: board).map { shortID($0.id) })
                #expect(onRay == (gates[level.index]?[name] ?? []), "Gate graph changed: \(level.index)/\(name)")
            }
        }
    }

    @Test func everyReachableStateMatchesTheReferenceGraphAndEveryLegalMoveStaysSafe() throws {
        for level in try load("levels-v2") {
            let original = level.makeBoard()
            let graph = dependencies(original)
            let names = original.pieces.map(\.id)
            let bit = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($0.element, UInt64(1) << $0.offset) })
            let full = (UInt64(1) << names.count) - 1
            var visited: Set<UInt64> = [0]
            var pending: [UInt64] = [0]
            var cursor = 0
            while cursor < pending.count {
                let state = pending[cursor]
                cursor += 1
                let removed = Set(names.filter { state & bit[$0]! != 0 })
                var current = original
                for id in removed { current.removePiece(id: id) }
                let expected = Set(names.filter { !removed.contains($0) && graph[$0]!.isSubset(of: removed) })
                let actual = Set(MoveValidator.availableMoves(board: current).map(\.id))
                #expect(actual == expected, "Runtime graph mismatch on level \(level.index), state \(state)")
                #expect(state == full || !actual.isEmpty, "Reachable dead end on \(level.index)")
                for id in actual {
                    var next = current
                    next.removePiece(id: id)
                    let nextMoves = Set(MoveValidator.availableMoves(board: next).map(\.id))
                    #expect(actual.subtracting([id]).isSubset(of: nextMoves))
                    let nextState = state | bit[id]!
                    if visited.insert(nextState).inserted { pending.append(nextState) }
                }
            }
            #expect(visited.contains(full))
        }
    }

    @Test func everyGateCellChangesAnAvailableMoveInAReachableState() throws {
        for level in try load("levels-v2") {
            let original = level.makeBoard()
            let graph = dependencies(original)
            for gate in original.obstacles {
                let key = try #require(gate.parameter)
                let without = dependencies(original, omittingGate: gate.id)
                var hasWitness = false
                for target in original.pieces where gatesOnRay(target, on: original).contains(where: { $0.id == gate.id }) {
                    var ancestors = without[target.id]!
                    while true {
                        let expanded = ancestors.union(ancestors.flatMap { graph[$0]! })
                        if expanded == ancestors { break }
                        ancestors = expanded
                    }
                    if ancestors.contains(key) || ancestors.contains(target.id) { continue }
                    var witness = original
                    var pending = ancestors
                    while !pending.isEmpty {
                        let legal = MoveValidator.availableMoves(board: witness).filter { pending.contains($0.id) }
                        try #require(!legal.isEmpty, "Counterfactual witness is unreachable")
                        let id = legal[0].id
                        witness.removePiece(id: id)
                        pending.remove(id)
                    }
                    #expect(!witness.isKeyGateOpen(gate))
                    #expect(!MoveValidator.canFlyOut(piece: target, board: witness))
                    witness.removeObstacle(id: gate.id)
                    if MoveValidator.canFlyOut(piece: target, board: witness) { hasWitness = true }
                }
                #expect(hasWitness, "Decorative/redundant gate: \(level.index)/\(gate.id)")
            }
        }
    }

    @Test func tutorialSharedCrossingAndIndependentDoubleBarrierKeepTheirSpecificLessons() throws {
        let levels = Dictionary(uniqueKeysWithValues: try load("levels-v2").map { ($0.index, $0) })
        let tutorial = try #require(levels[241])
        #expect(MoveValidator.availableMoves(board: tutorial.makeBoard()).map { shortID($0.id) } == ["KA"])

        let crossing = try #require(levels[251])
        let opened = try board(crossing, after: ["P", "KA"])
        let x = try #require(opened.pieces.first { shortID($0.id) == "X" })
        let y = try #require(opened.pieces.first { shortID($0.id) == "Y" })
        #expect(x.direction.isHorizontal != y.direction.isHorizontal)
        #expect(MoveValidator.canFlyOut(piece: x, board: opened))
        #expect(MoveValidator.canFlyOut(piece: y, board: opened))
        #expect(crossing.obstacles.count == 1)

        for number in [252, 259] {
            let level = try #require(levels[number])
            let targetName = number == 252 ? "X" : "Z"
            for prefix in [[], ["P", "KA"], ["Q", "KB"], ["P", "KA", "Q", "KB"], ["Q", "KB", "P", "KA"]] {
                let state = try board(level, after: prefix)
                let target = try #require(state.pieces.first { shortID($0.id) == targetName })
                #expect(MoveValidator.canFlyOut(piece: target, board: state) == (prefix.count == 4))
            }
        }
        for prefix in [["P", "KA", "X", "Q", "KB", "Y", "Z"], ["Q", "KB", "Y", "P", "KA", "Z", "X"]] {
            _ = try board(try #require(levels[259]), after: prefix)
        }
        for prefix in [["P", "Q", "KA", "U", "C", "KB", "X", "T", "Y"], ["Q", "P", "KA", "C", "KB", "Y", "X", "U", "T"]] {
            _ = try board(try #require(levels[260]), after: prefix)
        }
    }
}
