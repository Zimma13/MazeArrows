//
//  Obstacle.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Field elements that are not arrow pieces: walls, gates, portals, ice,
//  springs, destructible blocks. They live on a single cell and modify
//  how the head's exit lane is traversed by `MoveValidator`.
//

import Foundation

nonisolated enum ObstacleKind: String, Codable, Sendable {
    /// Impassable cell. A piece cannot fly out if its head's exit lane crosses one.
    case wall
    /// Pass-only-with-matching-direction (or color group) — used as a one-way.
    case gate
    /// Pair of portals: piece entering one tile exits from the other (same id pair).
    case portal
    /// Piece passing onto ice slides one extra cell along its direction.
    case ice
    /// Bounces the piece back if the head doesn't fully exit the board.
    /// In practice acts like a wall but in a different theme.
    case spring
    /// Destroyed when a bomb piece exits adjacent — otherwise a wall.
    case destructible
}

nonisolated struct Obstacle: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: ObstacleKind
    let cell: GridPoint
    /// For gates: which direction(s) the gate lets through.
    /// For portals: the matching pair id (string).
    /// For others: nil.
    let parameter: String?
    /// For gates: the color group restriction. nil = any.
    let colorGroup: Int?

    init(
        id: String,
        kind: ObstacleKind,
        cell: GridPoint,
        parameter: String? = nil,
        colorGroup: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.cell = cell
        self.parameter = parameter
        self.colorGroup = colorGroup
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, cell, parameter, colorGroup
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(ObstacleKind.self, forKey: .kind)
        cell = try c.decode(GridPoint.self, forKey: .cell)
        parameter = try? c.decode(String.self, forKey: .parameter)
        colorGroup = try? c.decode(Int.self, forKey: .colorGroup)
    }

    /// Gates store the allowed direction's raw string in `parameter`.
    var gateDirection: Direction? {
        guard let parameter else { return nil }
        return Direction(rawValue: parameter)
    }
}
