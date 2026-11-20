//
//  LevelValidator.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

nonisolated enum LevelValidationError: Error, CustomStringConvertible, Sendable {
    case pieceTooShort(String)
    case duplicateCellInPiece(String, GridPoint)
    case nonAdjacentCells(String)
    case selfCrossing(String)
    case selfBlockedExit(String, GridPoint)
    case outOfBounds(String, GridPoint)
    case overlappingPieces(String, String, GridPoint)
    case unsolvable
    case headSegmentMismatch(String, Direction)
    case cancelled
    case unsupportedRulesVersion(Int)
    case invalidVersion2Content(String)
    case duplicateIdentifier(String)
    case overlappingObstacles(String, String, GridPoint)
    case invalidKeyGateReference(String)
    case cyclicDependencies([String])

    var description: String {
        switch self {
        case .pieceTooShort(let id):
            return "Piece \(id) has fewer than 2 cells"
        case .duplicateCellInPiece(let id, let p):
            return "Piece \(id) has duplicate cell \(p)"
        case .nonAdjacentCells(let id):
            return "Piece \(id) has non-adjacent cells"
        case .selfCrossing(let id):
            return "Piece \(id) self-crosses"
        case .selfBlockedExit(let id, let p):
            return "Piece \(id) points through its own body at \(p)"
        case .outOfBounds(let id, let p):
            return "Piece \(id) has cell \(p) outside board"
        case .overlappingPieces(let a, let b, let p):
            return "Pieces \(a) and \(b) overlap at \(p)"
        case .unsolvable:
            return "Level has no solution"
        case .headSegmentMismatch(let id, let dir):
            return "Piece \(id): last body segment must point \(dir.rawValue)"
        case .cancelled:
            return "Validation was cancelled"
        case .unsupportedRulesVersion(let version):
            return "Unsupported level rules version \(version)"
        case .invalidVersion2Content(let reason):
            return "Invalid version 2 content: \(reason)"
        case .duplicateIdentifier(let id):
            return "Duplicate piece or obstacle id: \(id)"
        case .overlappingObstacles(let first, let second, let cell):
            return "Obstacles \(first) and \(second) overlap at \(cell)"
        case .invalidKeyGateReference(let id):
            return "Key gate \(id) must reference one existing key with the same symbol"
        case .cyclicDependencies(let ids):
            return "Cyclic removal dependencies: \(ids.joined(separator: ", "))"
        }
    }
}

nonisolated enum LevelValidator {
    static func validatePiece(_ piece: ArrowPiece, board: Board) -> LevelValidationError? {
        guard !Task.isCancelled else { return .cancelled }
        guard piece.cells.count >= 2 else {
            return .pieceTooShort(piece.id)
        }
        var seen = Set<GridPoint>()
        for (index, cell) in piece.cells.enumerated() {
            if index.isMultiple(of: 64), Task.isCancelled { return .cancelled }
            if !board.isInside(cell) {
                return .outOfBounds(piece.id, cell)
            }
            if !seen.insert(cell).inserted {
                return .duplicateCellInPiece(piece.id, cell)
            }
        }
        for i in 1..<piece.cells.count {
            if i.isMultiple(of: 64), Task.isCancelled { return .cancelled }
            let a = piece.cells[i - 1]
            let b = piece.cells[i]
            if abs(a.x - b.x) + abs(a.y - b.y) != 1 {
                return .nonAdjacentCells(piece.id)
            }
        }
        // The visual chevron points in `piece.direction` and sits at the head
        // (last cell). For a clean visual join, the last body segment must
        // travel in the same direction — otherwise the body bends one way
        // and the arrow head points elsewhere, leaving a visible mismatch.
        let last = piece.cells[piece.cells.count - 1]
        let prev = piece.cells[piece.cells.count - 2]
        let dx = last.x - prev.x
        let dy = last.y - prev.y
        if dx != piece.direction.dx || dy != piece.direction.dy {
            return .headSegmentMismatch(piece.id, piece.direction)
        }
        var probe = piece.headCell.moved(piece.direction)
        let body = Set(piece.cells.dropLast())
        while board.isInside(probe) {
            guard !Task.isCancelled else { return .cancelled }
            if body.contains(probe) {
                return .selfBlockedExit(piece.id, probe)
            }
            probe = probe.moved(piece.direction)
        }
        return nil
    }

    static func validateLevel(_ level: Level, requireSolvable: Bool = true) -> LevelValidationError? {
        guard !Task.isCancelled else { return .cancelled }
        guard level.rulesVersion == 1 || level.rulesVersion == 2 else {
            return .unsupportedRulesVersion(level.rulesVersion)
        }
        if level.rulesVersion == 2 {
            if let error = validateVersion2Contract(level) { return error }
        } else if level.obstacles.contains(where: { $0.kind == .keyGate }) {
            return .invalidVersion2Content("Key gates require rulesVersion 2")
        }
        let board = level.makeBoard()
        var globalOccupancy: [GridPoint: String] = [:]
        for piece in level.pieces {
            guard !Task.isCancelled else { return .cancelled }
            if let err = validatePiece(piece, board: board) { return err }
            for (index, cell) in piece.cells.enumerated() {
                if index.isMultiple(of: 64), Task.isCancelled { return .cancelled }
                if let other = globalOccupancy[cell] {
                    return .overlappingPieces(other, piece.id, cell)
                }
                globalOccupancy[cell] = piece.id
            }
        }
        // Obstacles must sit inside the board and not overlap any piece cell.
        var obstacleOccupancy: [GridPoint: String] = [:]
        for ob in level.obstacles {
            guard !Task.isCancelled else { return .cancelled }
            if !board.isInside(ob.cell) {
                return .outOfBounds(ob.id, ob.cell)
            }
            if let pieceId = globalOccupancy[ob.cell] {
                return .overlappingPieces(pieceId, ob.id, ob.cell)
            }
            if level.rulesVersion == 2, let other = obstacleOccupancy[ob.cell] {
                return .overlappingObstacles(other, ob.id, ob.cell)
            }
            obstacleOccupancy[ob.cell] = ob.id
        }
        if level.rulesVersion == 2, let error = validateAcyclicDependencies(board) {
            return error
        }
        if requireSolvable {
            guard !Task.isCancelled else { return .cancelled }
            if LevelSolver.solve(board: board) == nil {
                if Task.isCancelled { return .cancelled }
                return .unsolvable
            }
        }
        return nil
    }

    /// Version 2 is the monotone gate chapter: its limits keep the rules
    /// explicit and prevent accidental mixing with legacy side effects.
    private static func validateVersion2Contract(_ level: Level) -> LevelValidationError? {
        guard (1...256).contains(level.width), (1...256).contains(level.height),
              level.lives > 0, !level.pieces.isEmpty else {
            return .invalidVersion2Content("Expected a nonempty board of at most 256 × 256 and positive lives")
        }
        guard level.goal == .clearAll,
              level.pieces.allSatisfy({ $0.kind == .standard || $0.kind == .lockedKey }),
              level.obstacles.allSatisfy({ $0.kind == .keyGate }) else {
            return .invalidVersion2Content("Only standard arrows, keys, key gates and clearAll are supported")
        }
        let threeStars = level.threeStarMaxMistakes ?? 0
        guard threeStars >= 0, threeStars < Int.max else {
            return .invalidVersion2Content("Invalid three-star threshold")
        }
        let twoStars = level.twoStarMaxMistakes ?? max(1, threeStars + 1)
        guard threeStars >= 0, twoStars >= threeStars else {
            return .invalidVersion2Content("Star thresholds must be nonnegative and ordered")
        }

        var ids = Set<String>()
        for id in level.pieces.map(\.id) + level.obstacles.map(\.id) {
            guard !id.isEmpty else { return .invalidVersion2Content("Empty object identifier") }
            guard ids.insert(id).inserted else { return .duplicateIdentifier(id) }
        }
        let keys = level.pieces.filter { $0.kind == .lockedKey }
        guard (1...2).contains(keys.count), (1...4).contains(level.obstacles.count) else {
            return .invalidVersion2Content("Expected one or two keys and one to four gate cells")
        }
        var keyByID: [String: ArrowPiece] = [:]
        var symbols = Set<Int>()
        for key in keys {
            guard let group = key.colorGroup, (1...2).contains(group), symbols.insert(group).inserted else {
                return .invalidVersion2Content("Each key needs its own circle (1) or diamond (2) symbol")
            }
            keyByID[key.id] = key
        }
        var referencedKeys = Set<String>()
        for gate in level.obstacles {
            guard let keyID = gate.parameter, let key = keyByID[keyID],
                  gate.colorGroup == key.colorGroup else { return .invalidKeyGateReference(gate.id) }
            referencedKeys.insert(keyID)
        }
        guard referencedKeys == Set(keys.map(\.id)) else {
            return .invalidVersion2Content("Every key must open at least one gate")
        }
        return nil
    }

    /// Build dependencies from the actual full rays, including every gate
    /// key, not only the nearest visible collision. A self-gated key and a
    /// mutual-key deadlock are rejected even when solving is not requested.
    private static func validateAcyclicDependencies(_ board: Board) -> LevelValidationError? {
        var dependencies: [String: Set<String>] = [:]
        var dependents: [String: Set<String>] = [:]
        for piece in board.pieces {
            guard !Task.isCancelled else { return .cancelled }
            let required = MoveValidator.blockers(for: piece, board: board)
            dependencies[piece.id] = required
            for id in required { dependents[id, default: []].insert(piece.id) }
        }
        var ready = dependencies.compactMap { $0.value.isEmpty ? $0.key : nil }
        var removed = Set<String>()
        while let id = ready.popLast() {
            guard !Task.isCancelled else { return .cancelled }
            guard removed.insert(id).inserted else { continue }
            for dependent in dependents[id, default: []] {
                dependencies[dependent]?.remove(id)
                if dependencies[dependent]?.isEmpty == true { ready.append(dependent) }
            }
        }
        let blocked = board.pieces.map(\.id).filter { !removed.contains($0) }.sorted()
        return blocked.isEmpty ? nil : .cyclicDependencies(blocked)
    }
}
