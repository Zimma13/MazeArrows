//
//  MoveValidator.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Core collision logic. A piece may fly out if every cell of its body can
//  travel along the direction until fully outside the board without ever
//  occupying a cell currently held by a different piece — and without
//  crossing an impassable obstacle.
//

import Foundation

nonisolated enum MoveValidator {

    /// Returns `true` if `piece` can leave the board in its direction without
    /// colliding with any other piece on `board`.
    ///
    /// Because pieces leave the board by feeding through their own labyrinth
    /// path, only the head's straight exit lane needs to be clear of other
    /// pieces. The body slides along the original path — cells beside the
    /// body do NOT block the move. Only an obstruction directly in front of
    /// the head can stop it.
    static func canFlyOut(piece: ArrowPiece, board: Board) -> Bool {
        let occupied = board.occupiedMap()
        let obstacles = board.obstacleMap()
        return canFlyOut(piece: piece, board: board, occupied: occupied, obstacles: obstacles)
    }

    /// Cached-occupancy variant used in solver hot loops.
    static func canFlyOut(
        piece: ArrowPiece,
        board: Board,
        occupied: [GridPoint: String],
        obstacles: [GridPoint: Obstacle]
    ) -> Bool {
        guard !Task.isCancelled else { return false }
        // Piece-kind gates first.
        if !canActOnKindRule(piece: piece, board: board) { return false }

        var cell = piece.headCell
        let direction = piece.direction
        while true {
            guard !Task.isCancelled else { return false }
            let next = cell.moved(direction)
            if !board.isInside(next) { return true }
            if let blockerId = occupied[next], blockerId != piece.id { return false }
            if let ob = obstacles[next], !obstaclePassable(ob, by: piece, direction: direction) {
                return false
            }
            cell = next
        }
    }

    /// Frozen/lock-key gates that exist regardless of the lane.
    static func canActOnKindRule(piece: ArrowPiece, board: Board) -> Bool {
        switch piece.kind {
        case .frozen:
            let threshold = piece.frozenUnlockNeighbors ?? 1
            return board.removedPieceCount >= threshold
        case .lockedLock:
            // Lock cannot move until its matching key (same colorGroup) is gone.
            guard let group = piece.colorGroup else { return true }
            for other in board.pieces {
                guard !Task.isCancelled else { return false }
                if other.id != piece.id,
                   other.kind == .lockedKey,
                   other.colorGroup == group {
                    return false
                }
            }
            return true
        default:
            return true
        }
    }

    /// Returns whether `piece` may pass through obstacle `ob` while moving
    /// in `direction`. Walls block everyone. Gates let through matching
    /// direction & color. Portals are passable (teleport handled elsewhere).
    /// Ice and springs are passable. Destructibles block unless `piece` is a bomb.
    static func obstaclePassable(_ ob: Obstacle, by piece: ArrowPiece, direction: Direction) -> Bool {
        switch ob.kind {
        case .wall:
            return false
        case .gate:
            // Gate direction must match. Color group, if set, must match too.
            if let gateDir = ob.gateDirection, gateDir != direction { return false }
            if let group = ob.colorGroup, group != piece.colorGroup { return false }
            return true
        case .portal:
            return true
        case .ice:
            return true
        case .spring:
            return true
        case .destructible:
            return piece.kind == .bomb
        }
    }

    /// IDs of pieces that block `piece` along the head's exit lane.
    static func blockers(for piece: ArrowPiece, board: Board) -> Set<String> {
        let occupied = board.occupiedMap()
        var result = Set<String>()
        var cell = piece.headCell
        while true {
            let next = cell.moved(piece.direction)
            if !board.isInside(next) { break }
            if let blockerId = occupied[next], blockerId != piece.id {
                result.insert(blockerId)
            }
            cell = next
        }
        return result
    }

    /// First obstructing cell along the head's exit lane.
    /// Returns nil if the piece can fly out cleanly.
    static func firstCollision(for piece: ArrowPiece, board: Board) -> GridPoint? {
        let occupied = board.occupiedMap()
        let obstacles = board.obstacleMap()
        var cell = piece.headCell
        while true {
            let next = cell.moved(piece.direction)
            if !board.isInside(next) { return nil }
            if let id = occupied[next], id != piece.id { return next }
            if let ob = obstacles[next], !obstaclePassable(ob, by: piece, direction: piece.direction) {
                return next
            }
            cell = next
        }
    }

    /// All pieces on the board that can currently fly out.
    static func availableMoves(board: Board) -> [ArrowPiece] {
        let occupied = board.occupiedMap()
        let obstacles = board.obstacleMap()
        guard !Task.isCancelled else { return [] }
        var available: [ArrowPiece] = []
        for piece in board.pieces {
            guard !Task.isCancelled else { return [] }
            if canFlyOut(piece: piece, board: board, occupied: occupied, obstacles: obstacles) {
                available.append(piece)
            }
        }
        return available
    }

    /// Number of cells of `cellSize` the piece must travel for its entire body
    /// to exit the board (extra padding included).
    static func exitDistanceInCells(for piece: ArrowPiece, board: Board) -> Int {
        let pad = piece.kind == .heavy ? 3 : 2
        switch piece.direction {
        case .right:
            let maxX = piece.cells.map(\.x).max() ?? 0
            return max(0, board.width - maxX) + pad
        case .left:
            let minX = piece.cells.map(\.x).min() ?? 0
            return minX + pad
        case .down:
            let maxY = piece.cells.map(\.y).max() ?? 0
            return max(0, board.height - maxY) + pad
        case .up:
            let minY = piece.cells.map(\.y).min() ?? 0
            return minY + pad
        }
    }
}
