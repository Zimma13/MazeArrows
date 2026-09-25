//
//  BoardGeometry.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Maps grid coordinates (y grows down) into SpriteKit scene coordinates
//  (y grows up).
//

import CoreGraphics
import Foundation

struct BoardGeometry: Sendable {
    let width: Int
    let height: Int
    let cellSize: CGFloat
    let origin: CGPoint  // bottom-left corner of the (0,0)-grid cell in scene coords

    /// Build a geometry sized to fill the smaller of `availableWidth`/`availableHeight`,
    /// centered inside the area.
    init(boardWidth: Int, boardHeight: Int, availableSize: CGSize, padding: CGFloat = 34) {
        let usableW = max(1, availableSize.width - padding * 2)
        let usableH = max(1, availableSize.height - padding * 2)
        let raw = min(usableW / CGFloat(boardWidth), usableH / CGFloat(boardHeight))
        let cellSize = max(1, raw)
        let totalW = cellSize * CGFloat(boardWidth)
        let totalH = cellSize * CGFloat(boardHeight)
        let originX = (availableSize.width - totalW) / 2
        let originY = (availableSize.height - totalH) / 2
        self.width = boardWidth
        self.height = boardHeight
        self.cellSize = cellSize
        self.origin = CGPoint(x: originX, y: originY)
    }

    /// Center of the grid cell in scene coords. `y` grid grows top→down, scene y grows up.
    func point(for cell: GridPoint) -> CGPoint {
        let cx = origin.x + (CGFloat(cell.x) + 0.5) * cellSize
        // Flip y
        let flippedY = CGFloat(height - 1 - cell.y) + 0.5
        let cy = origin.y + flippedY * cellSize
        return CGPoint(x: cx, y: cy)
    }

    func cell(at point: CGPoint) -> GridPoint? {
        let localX = point.x - origin.x
        let localY = point.y - origin.y
        guard localX >= 0, localY >= 0 else { return nil }

        let x = Int(localX / cellSize)
        let flippedY = Int(localY / cellSize)
        let y = height - 1 - flippedY
        guard x >= 0, x < width, y >= 0, y < height else { return nil }

        return GridPoint(x: x, y: y)
    }

    func boardSize() -> CGSize {
        CGSize(width: cellSize * CGFloat(width), height: cellSize * CGFloat(height))
    }
}
