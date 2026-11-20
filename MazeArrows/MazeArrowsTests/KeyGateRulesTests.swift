import Foundation
import Testing
@testable import MazeArrows

struct KeyGateRulesTests {
    private func arrow(
        _ id: String, _ x: Int, _ y: Int,
        direction: Direction = .right, keyGroup: Int? = nil
    ) -> ArrowPiece {
        ArrowPiece(
            id: id,
            cells: [GridPoint(x: x, y: y), GridPoint(x: x + direction.dx, y: y + direction.dy)],
            direction: direction,
            kind: keyGroup == nil ? .standard : .lockedKey,
            colorGroup: keyGroup
        )
    }

    private func gate(_ id: String, _ x: Int, _ y: Int, key: String = "key-a", group: Int = 1) -> Obstacle {
        Obstacle(id: id, kind: .keyGate, cell: GridPoint(x: x, y: y), parameter: key, colorGroup: group)
    }

    private func level(pieces: [ArrowPiece], gates: [Obstacle]) -> Level {
        Level(
            id: "gate-test", index: 241, difficulty: .easy,
            width: 9, height: 9, lives: 4, pieces: pieces,
            obstacles: gates, rulesVersion: 2
        )
    }

    @Test func aKeyOpensEveryLinkedGateWithoutMovingOtherArrows() throws {
        let key = arrow("key-a", 0, 0, keyGroup: 1)
        let first = arrow("first", 0, 2)
        let second = arrow("second", 0, 4)
        let gates = [gate("a1", 4, 2), gate("a2", 4, 4)]
        let original = level(pieces: [key, first, second], gates: gates)
        #expect(LevelValidator.validateLevel(original) == nil)
        var board = original.makeBoard()
        #expect(board.keyGates(forKeyID: key.id).count == 2)
        #expect(MoveValidator.availableMoves(board: board).map(\.id) == [key.id])
        #expect(gates.allSatisfy { !board.isKeyGateOpen($0) })

        board.removePiece(id: key.id)

        #expect(gates.allSatisfy { board.isKeyGateOpen($0) })
        #expect(board.pieces == [first, second])
        #expect(Set(MoveValidator.availableMoves(board: board).map(\.id)) == [first.id, second.id])
        #expect(LevelSolver.solve(board: board)?.count == 2)
    }

    @Test func twoGatesOnOneRayRequireBothIndependentKeys() {
        let firstKey = arrow("key-a", 0, 0, keyGroup: 1)
        let secondKey = arrow("key-b", 6, 8, keyGroup: 2)
        let target = arrow("target", 0, 3)
        let firstGate = gate("a", 3, 3)
        let secondGate = gate("b", 5, 3, key: secondKey.id, group: 2)
        let original = level(pieces: [firstKey, secondKey, target], gates: [firstGate, secondGate])
        #expect(LevelValidator.validateLevel(original) == nil)
        #expect(MoveValidator.blockers(for: target, board: original.makeBoard()) == [firstKey.id, secondKey.id])
        for removedKey in [firstKey, secondKey] {
            var board = original.makeBoard()
            #expect(!MoveValidator.canFlyOut(piece: target, board: board))
            board.removePiece(id: removedKey.id)
            #expect(!MoveValidator.canFlyOut(piece: target, board: board))
            let otherGate = removedKey.id == firstKey.id ? secondGate : firstGate
            #expect(MoveValidator.firstCollision(for: target, board: board) == otherGate.cell)
            board.removePiece(id: removedKey.id == firstKey.id ? secondKey.id : firstKey.id)
            #expect(MoveValidator.canFlyOut(piece: target, board: board))
        }
    }

    @Test func openGateDoesNotHideASecondArrowBlocker() {
        let key = arrow("key-a", 0, 0, keyGroup: 1)
        let target = arrow("target", 0, 3)
        let blocker = arrow("blocker", 7, 3, direction: .down)
        let door = gate("a", 3, 3)
        var board = level(pieces: [key, target, blocker], gates: [door]).makeBoard()
        #expect(MoveValidator.firstCollision(for: target, board: board) == door.cell)
        board.removePiece(id: key.id)
        #expect(MoveValidator.firstCollision(for: target, board: board) == blocker.tailCell)
        #expect(!MoveValidator.canFlyOut(piece: target, board: board))
        board.removePiece(id: blocker.id)
        #expect(MoveValidator.firstCollision(for: target, board: board) == nil)
        #expect(MoveValidator.canFlyOut(piece: target, board: board))
    }

    @Test func oneGateCanBlockTwoPerpendicularRays() {
        let key = arrow("key-a", 0, 8, keyGroup: 1)
        let horizontal = arrow("horizontal", 0, 4)
        let vertical = arrow("vertical", 4, 0, direction: .down)
        let door = gate("shared", 4, 4)
        let original = level(pieces: [key, horizontal, vertical], gates: [door])
        #expect(LevelValidator.validateLevel(original) == nil)
        var board = original.makeBoard()
        #expect(!MoveValidator.canFlyOut(piece: horizontal, board: board))
        #expect(!MoveValidator.canFlyOut(piece: vertical, board: board))
        board.removePiece(id: key.id)
        #expect(MoveValidator.canFlyOut(piece: horizontal, board: board))
        #expect(MoveValidator.canFlyOut(piece: vertical, board: board))
    }

    @Test func gateBesideTheBodyDoesNotBlockTheHeadExitLane() {
        let key = arrow("key-a", 0, 8, keyGroup: 1)
        let target = ArrowPiece(
            id: "target",
            cells: [GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1)],
            direction: .right
        )
        let door = gate("beside-body", 1, 0)
        let board = level(pieces: [key, target], gates: [door]).makeBoard()
        #expect(!board.isKeyGateOpen(door))
        #expect(MoveValidator.canFlyOut(piece: target, board: board))
        #expect(MoveValidator.firstCollision(for: target, board: board) == nil)
    }

    @Test func everyLegalOrderOfIndependentPreparationsRemainsSolvable() {
        let keyA = arrow("key-a", 0, 0, keyGroup: 1)
        let keyB = arrow("key-b", 6, 8, keyGroup: 2)
        let target = arrow("target", 0, 3)
        let independent = arrow("independent", 8, 5, direction: .up)
        let original = level(pieces: [keyA, keyB, target, independent], gates: [
            gate("a", 3, 3), gate("b", 5, 3, key: keyB.id, group: 2)
        ])
        var states = Set<Set<String>>()
        func visit(_ board: Board) {
            guard states.insert(Set(board.pieces.map(\.id))).inserted else { return }
            #expect(LevelSolver.solve(board: board) != nil)
            let moves = MoveValidator.availableMoves(board: board)
            for move in moves {
                var next = board
                next.removePiece(id: move.id)
                for stillAvailable in moves where stillAvailable.id != move.id {
                    #expect(MoveValidator.canFlyOut(piece: stillAvailable, board: next))
                }
                visit(next)
            }
        }
        visit(original.makeBoard())
        #expect(states.count > 5)
    }

    @Test func blockedKeyDoesNotOpenUntilItsLegalExitAndHintFindsPreparation() {
        let key = arrow("key-a", 0, 0, keyGroup: 1)
        let blocker = arrow("preparation", 3, 0, direction: .down)
        let target = arrow("target", 0, 4)
        let door = gate("a", 4, 4)
        var board = level(pieces: [key, blocker, target], gates: [door]).makeBoard()
        #expect(!MoveValidator.canFlyOut(piece: key, board: board))
        #expect(!board.isKeyGateOpen(door))
        #expect(LevelSolver.nextHintPiece(board: board)?.id == blocker.id)
        board.removePiece(id: blocker.id)
        #expect(MoveValidator.canFlyOut(piece: key, board: board))
        #expect(!board.isKeyGateOpen(door))
        board.removePiece(id: key.id)
        #expect(board.isKeyGateOpen(door))
    }

    @Test func undoAndResetRestoreWholeGroupsAndBoardCopiesRetainInitialKeys() {
        let key = arrow("key-a", 0, 0, keyGroup: 1)
        let target = arrow("target", 0, 3)
        let gates = [gate("a1", 3, 3), gate("a2", 6, 3)]
        let original = level(pieces: [key, target], gates: gates)
        var board = original.makeBoard()
        board.removePiece(id: key.id)
        var solverCopy = board
        solverCopy.removePiece(id: target.id)
        #expect(gates.allSatisfy { solverCopy.isKeyGateOpen($0) })
        solverCopy.append(target)
        #expect(gates.allSatisfy { solverCopy.isKeyGateOpen($0) })
        solverCopy.append(key)
        #expect(gates.allSatisfy { !solverCopy.isKeyGateOpen($0) })
        #expect(!MoveValidator.canFlyOut(piece: target, board: solverCopy))
        #expect(gates.allSatisfy { board.isKeyGateOpen($0) })
        let reset = original.makeBoard()
        #expect(gates.allSatisfy { !reset.isKeyGateOpen($0) })
        #expect(reset.pieces == original.pieces)
    }

    @Test func missingOrNonKeyReferencesNeverCountAsRemovedKeys() {
        let target = arrow("target", 0, 3)
        let invalidGates = [gate("missing", 3, 3, key: "absent"), gate("ordinary", 6, 3, key: target.id)]
        var board = Board(width: 9, height: 9, pieces: [target], obstacles: invalidGates)
        #expect(invalidGates.allSatisfy { !board.isKeyGateOpen($0) })
        board.removePiece(id: target.id)
        #expect(invalidGates.allSatisfy { !board.isKeyGateOpen($0) })
        #expect(!MoveValidator.obstaclePassable(invalidGates[0], by: target, direction: .right))
    }

    @Test func ownGateAndMutualKeyCyclesAreRejected() {
        let key = arrow("key-a", 0, 2, keyGroup: 1)
        let ownGate = level(pieces: [key], gates: [gate("a", 4, 2)])
        #expect(!MoveValidator.canFlyOut(piece: key, board: ownGate.makeBoard()))
        #expect(MoveValidator.blockers(for: key, board: ownGate.makeBoard()) == [key.id])
        #expect(LevelSolver.solve(board: ownGate.makeBoard()) == nil)
        guard case .cyclicDependencies = LevelValidator.validateLevel(ownGate, requireSolvable: false) else {
            Issue.record("Self-gated key must be rejected as a cycle")
            return
        }

        let secondKey = arrow("key-b", 0, 4, keyGroup: 2)
        let mutual = level(pieces: [key, secondKey], gates: [
            gate("a", 4, 4), gate("b", 4, 2, key: secondKey.id, group: 2)
        ])
        guard case .cyclicDependencies = LevelValidator.validateLevel(mutual, requireSolvable: false) else {
            Issue.record("Mutually gated keys must be rejected")
            return
        }
        #expect(LevelSolver.solve(board: mutual.makeBoard()) == nil)
    }

    @Test func indirectKeyCycleThroughAnOrdinaryArrowIsRejected() {
        let key = arrow("key-a", 0, 2, keyGroup: 1)
        let target = arrow("target", 3, 2, direction: .down)
        let original = level(pieces: [key, target], gates: [gate("a", 3, 5)])
        guard case .cyclicDependencies = LevelValidator.validateLevel(original, requireSolvable: false) else {
            Issue.record("Key → ordinary arrow → key cycle must be rejected")
            return
        }
    }

    @Test func versionTwoRejectsOverlappingGatesDuplicateIDsAndWrongSymbols() {
        let key = arrow("key-a", 0, 0, keyGroup: 1)
        let target = arrow("target", 0, 3)
        let pieces = [key, target]
        let overlap = level(pieces: pieces, gates: [gate("a", 3, 3), gate("b", 3, 3)])
        guard case .overlappingObstacles = LevelValidator.validateLevel(overlap) else {
            Issue.record("Two gates cannot share a cell")
            return
        }
        let duplicate = level(pieces: pieces, gates: [gate(key.id, 3, 3)])
        guard case .duplicateIdentifier = LevelValidator.validateLevel(duplicate) else {
            Issue.record("Piece and obstacle identifiers must be unique")
            return
        }
        let wrongSymbol = level(pieces: pieces, gates: [gate("a", 3, 3, group: 2)])
        guard case .invalidKeyGateReference = LevelValidator.validateLevel(wrongSymbol) else {
            Issue.record("Linked key and gate symbols must agree")
            return
        }
    }

    @Test func legacyDirectionalGateStillFiltersDirectionAndColor() {
        var piece = arrow("ordinary", 0, 0)
        piece.colorGroup = 7
        let legacy = Obstacle(id: "old", kind: .gate, cell: GridPoint(x: 3, y: 0), parameter: "right", colorGroup: 7)
        let board = Board(width: 9, height: 9, pieces: [piece], obstacles: [legacy])
        #expect(MoveValidator.canFlyOut(piece: piece, board: board))
        #expect(MoveValidator.obstaclePassable(legacy, by: piece, direction: .right))
        #expect(!MoveValidator.obstaclePassable(legacy, by: piece, direction: .left))
        piece.colorGroup = 8
        #expect(!MoveValidator.obstaclePassable(legacy, by: piece, direction: .right))
        #expect(!board.isKeyGateOpen(legacy))
    }

    @Test func legacyFrozenStillCountsAnyRemovedArrowAndLegacyLockUsesColor() {
        var frozen = arrow("frozen", 0, 0)
        frozen.kind = .frozen
        frozen.frozenUnlockNeighbors = 1
        let remote = arrow("remote", 7, 8)
        var board = Board(width: 9, height: 9, pieces: [frozen, remote])
        #expect(!MoveValidator.canFlyOut(piece: frozen, board: board))
        board.removePiece(id: remote.id)
        #expect(MoveValidator.canFlyOut(piece: frozen, board: board))
        board.append(remote)
        #expect(!MoveValidator.canFlyOut(piece: frozen, board: board))

        var lock = arrow("lock", 0, 3)
        lock.kind = .lockedLock
        lock.colorGroup = 7
        let key = arrow("old-key", 0, 0, keyGroup: 7)
        var lockBoard = Board(width: 9, height: 9, pieces: [lock, key])
        #expect(!MoveValidator.canFlyOut(piece: lock, board: lockBoard))
        lockBoard.removePiece(id: key.id)
        #expect(MoveValidator.canFlyOut(piece: lock, board: lockBoard))
    }

    @Test func versionTwoRoundTripsAndUnknownOrMalformedRulesDoNotFallBack() throws {
        let source = level(
            pieces: [arrow("key-a", 0, 0, keyGroup: 1), arrow("target", 0, 3)],
            gates: [gate("a", 4, 3)]
        )
        let encoded = try JSONEncoder().encode(source)
        #expect(try JSONDecoder().decode(Level.self, from: encoded) == source)
        let original = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        func assertRejected(_ object: [String: Any]) throws {
            let data = try JSONSerialization.data(withJSONObject: object)
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(Level.self, from: data) }
        }

        var malformed = original
        malformed["rulesVersion"] = 999
        try assertRejected(malformed)
        malformed = original
        malformed["obstacles"] = "not an obstacle array"
        try assertRejected(malformed)
        malformed = original
        malformed.removeValue(forKey: "obstacles")
        try assertRejected(malformed)

        for (field, value) in [("kind", "futureGate"), ("parameter", 123), ("colorGroup", "circle")] as [(String, Any)] {
            malformed = original
            var obstacles = try #require(malformed["obstacles"] as? [[String: Any]])
            obstacles[0][field] = value
            malformed["obstacles"] = obstacles
            try assertRejected(malformed)
        }
        malformed = original
        var pieces = try #require(malformed["pieces"] as? [[String: Any]])
        pieces[0]["kind"] = "futureKey"
        malformed["pieces"] = pieces
        try assertRejected(malformed)
        malformed = original
        malformed["goal"] = ["kind": "futureGoal"]
        try assertRejected(malformed)
    }

    @Test func absentVersionKeepsLegacyOptionalFieldFallbacks() throws {
        let source = level(pieces: [arrow("key-a", 0, 0, keyGroup: 1)], gates: [gate("a", 4, 3)])
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        object.removeValue(forKey: "rulesVersion")
        object["obstacles"] = [["kind": "unknownLegacyPlaceholder"]]
        object["goal"] = ["kind": "unknownLegacyGoal"]
        let legacy = try JSONDecoder().decode(Level.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.rulesVersion == 1)
        #expect(legacy.obstacles.isEmpty)
        #expect(legacy.goal == .clearAll)
    }

    @Test func sharedGateLevelsKeepExactReferencesAndNeverImportAsStoryProgress() throws {
        let original = level(pieces: [
            arrow("key-a", 0, 0, keyGroup: 1), arrow("key-b", 6, 8, keyGroup: 2), arrow("target", 0, 3)
        ], gates: [gate("a", 3, 3), gate("b", 5, 3, key: "key-b", group: 2)])
        let encoded = try #require(LevelShareCodec.encode(original))
        let raw = try (encoded as NSData).decompressed(using: .zlib) as Data
        #expect(Array(raw.prefix(3)) == [0x4D, 0x5A, 3])
        let url = try #require(LevelShareCodec.shareURL(for: original))
        let imported = try #require(LevelShareCodec.level(from: url))
        #expect(imported.rulesVersion == 2)
        #expect(imported.id.hasPrefix("shared_"))
        #expect(imported.index == 0)
        #expect(imported.pieces == original.pieces)
        #expect(imported.obstacles == original.obstacles)
        #expect(imported.goal == original.goal)
        #expect(imported.lives == original.lives)
        #expect(LevelValidator.validateLevel(imported) == nil)
        var board = imported.makeBoard()
        board.removePiece(id: "key-a")
        #expect(board.isKeyGateOpen(imported.obstacles[0]))
        #expect(!board.isKeyGateOpen(imported.obstacles[1]))
    }

    @Test func legacyBinaryShareFixturesRemainByteCompatible() throws {
        // Existing wire v1 (plain) and wire v2 (RGB palette) are distinct
        // from the level's rulesVersion; both continue to decode as rules v1.
        let plain = Data([0x4D, 0x5A, 1, 9, 9, 4, 0, 1, 0, 0, 0, 0, 2, 0, 0, 3])
        let palette = Data([0x4D, 0x5A, 2, 9, 9, 4, 0, 1, 0, 1, 255, 0, 0, 0, 2, 0, 2, 0, 0, 3])
        for fixture in [plain, palette] {
            let compressed = try (fixture as NSData).compressed(using: .zlib) as Data
            let imported = try #require(LevelShareCodec.decode(compressed))
            #expect(imported.rulesVersion == 1)
            #expect(imported.obstacles.isEmpty)
            #expect(imported.pieces.count == 1)
            let encoded = try #require(LevelShareCodec.encode(imported))
            let exported = try (encoded as NSData).decompressed(using: .zlib) as Data
            #expect(exported == fixture)
        }
    }

    @Test func malformedVersionThreeSharingCannotSilentlyDropGates() throws {
        let original = level(
            pieces: [arrow("key-a", 0, 0, keyGroup: 1), arrow("target", 0, 3)],
            gates: [gate("a", 4, 3)]
        )
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object["obstacles"] = "broken"
        var payload = Data([0x4D, 0x5A, 3])
        payload.append(try JSONSerialization.data(withJSONObject: object))
        let compressed = try (payload as NSData).compressed(using: .zlib) as Data
        #expect(LevelShareCodec.decode(compressed) == nil)

        let invalid = level(pieces: original.pieces, gates: [gate("unknown-key", 4, 3, key: "missing")])
        #expect(LevelShareCodec.encode(invalid) == nil)
        #expect(LevelShareCodec.shareURL(for: invalid) == nil)
    }
}
