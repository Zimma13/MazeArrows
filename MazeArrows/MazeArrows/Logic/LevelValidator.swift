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
        for ob in level.obstacles {
            guard !Task.isCancelled else { return .cancelled }
            if !board.isInside(ob.cell) {
                return .outOfBounds(ob.id, ob.cell)
            }
            if let pieceId = globalOccupancy[ob.cell] {
                return .overlappingPieces(pieceId, ob.id, ob.cell)
            }
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
}
