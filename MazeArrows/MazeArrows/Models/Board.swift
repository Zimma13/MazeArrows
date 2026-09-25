//
//  Board.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

nonisolated struct Board: Sendable {
    let width: Int
    let height: Int
    private(set) var pieces: [ArrowPiece]
    private(set) var obstacles: [Obstacle]
    /// Total number of pieces present at level start. Used by `.frozen`
    /// unfreezing logic which counts neighbors that have already been removed.
    let initialPieceCount: Int

    init(width: Int, height: Int, pieces: [ArrowPiece], obstacles: [Obstacle] = []) {
        self.width = width
        self.height = height
        self.pieces = pieces
        self.obstacles = obstacles
        self.initialPieceCount = pieces.count
    }

    func isInside(_ point: GridPoint) -> Bool {
        point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
    }

    func piece(at point: GridPoint) -> ArrowPiece? {
        pieces.first { $0.cells.contains(point) }
    }

    func obstacle(at point: GridPoint) -> Obstacle? {
        obstacles.first { $0.cell == point }
    }

    func occupiedMap() -> [GridPoint: String] {
        var map: [GridPoint: String] = [:]
        map.reserveCapacity(pieces.reduce(0) { $0 + $1.cells.count })
        for piece in pieces {
            guard !Task.isCancelled else { return map }
            for (index, cell) in piece.cells.enumerated() {
                if index.isMultiple(of: 64), Task.isCancelled { return map }
                map[cell] = piece.id
            }
        }
        return map
    }

    func obstacleMap() -> [GridPoint: Obstacle] {
        var map: [GridPoint: Obstacle] = [:]
        map.reserveCapacity(obstacles.count)
        for obstacle in obstacles {
            guard !Task.isCancelled else { return map }
            map[obstacle.cell] = obstacle
        }
        return map
    }

    mutating func removePiece(id: String) {
        pieces.removeAll { $0.id == id }
    }

    mutating func append(_ piece: ArrowPiece) {
        pieces.append(piece)
    }

    mutating func replaceAll(with newPieces: [ArrowPiece]) {
        pieces = newPieces
    }

    mutating func removeObstacle(id: String) {
        obstacles.removeAll { $0.id == id }
    }

    /// Number of arrow pieces that have already been removed since level start.
    var removedPieceCount: Int { max(0, initialPieceCount - pieces.count) }

    /// Mutate an individual piece in place (e.g. update cracks, lift frozen).
    mutating func updatePiece(id: String, _ transform: (inout ArrowPiece) -> Void) {
        guard let idx = pieces.firstIndex(where: { $0.id == id }) else { return }
        transform(&pieces[idx])
    }
}
