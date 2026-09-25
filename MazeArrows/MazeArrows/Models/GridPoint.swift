//
//  GridPoint.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Grid coordinate. `x` grows left→right, `y` grows top→bottom.
//

import Foundation

nonisolated struct GridPoint: Hashable, Codable, Sendable {
    let x: Int
    let y: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    func moved(_ direction: Direction) -> GridPoint {
        GridPoint(x: x + direction.dx, y: y + direction.dy)
    }

    func moved(_ direction: Direction, by steps: Int) -> GridPoint {
        GridPoint(x: x + direction.dx * steps, y: y + direction.dy * steps)
    }
}

extension GridPoint: CustomDebugStringConvertible {
    var debugDescription: String { "(\(x),\(y))" }
}
