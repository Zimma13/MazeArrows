//
//  ArrowPiece.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  A single maze-arrow figure. `cells` is the full body of the piece in grid
//  coordinates. The last cell is the visual tip — the arrow-head points
//  in `direction`.
//

import Foundation

nonisolated enum PieceKind: String, Codable, Sendable {
    case standard
    /// Thicker stroke, longer fly distance, more momentum.
    case heavy
    /// Cracks on first failed tap, breaks on second (costs extra life).
    case fragile
    /// Iced-up — won't fly until N neighbors have been removed.
    case frozen
    /// Has two possible directions — player chooses via swipe.
    case double
    /// Paired with a "key" piece via `colorGroup`. Lock won't move until key is removed.
    case lockedLock
    /// Marks a key piece. Frees its matching lock(s) on exit.
    case lockedKey
    /// On exit, destroys all adjacent pieces (and destructible obstacles).
    case bomb
    /// On exit, triggers exit of the linked piece (see `chainedPieceId`).
    case chain
}

nonisolated struct ArrowPiece: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var cells: [GridPoint]
    var direction: Direction
    var kind: PieceKind
    /// Color group — used for visual variety, key/lock pairing, and color-group goals.
    var colorGroup: Int?
    /// Second direction for `.double` pieces. Player swipes to pick.
    var secondaryDirection: Direction?
    /// For `.frozen`: how many neighbors need to be removed before this unfreezes.
    var frozenUnlockNeighbors: Int?
    /// For `.chain`: the piece id whose exit gets auto-triggered after this one.
    var chainedPieceId: String?
    /// For `.fragile`: damage taken so far (0 = pristine, 1 = cracked, 2 = broken).
    var crackLevel: Int

    init(
        id: String,
        cells: [GridPoint],
        direction: Direction,
        kind: PieceKind = .standard,
        colorGroup: Int? = nil,
        secondaryDirection: Direction? = nil,
        frozenUnlockNeighbors: Int? = nil,
        chainedPieceId: String? = nil,
        crackLevel: Int = 0
    ) {
        self.id = id
        self.cells = cells
        self.direction = direction
        self.kind = kind
        self.colorGroup = colorGroup
        self.secondaryDirection = secondaryDirection
        self.frozenUnlockNeighbors = frozenUnlockNeighbors
        self.chainedPieceId = chainedPieceId
        self.crackLevel = crackLevel
    }

    enum CodingKeys: String, CodingKey {
        case id, cells, direction, kind, colorGroup
        case secondaryDirection, frozenUnlockNeighbors, chainedPieceId, crackLevel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        cells = try c.decode([GridPoint].self, forKey: .cells)
        direction = try c.decode(Direction.self, forKey: .direction)
        kind = (try? c.decode(PieceKind.self, forKey: .kind)) ?? .standard
        colorGroup = try? c.decode(Int.self, forKey: .colorGroup)
        secondaryDirection = try? c.decode(Direction.self, forKey: .secondaryDirection)
        frozenUnlockNeighbors = try? c.decode(Int.self, forKey: .frozenUnlockNeighbors)
        chainedPieceId = try? c.decode(String.self, forKey: .chainedPieceId)
        crackLevel = (try? c.decode(Int.self, forKey: .crackLevel)) ?? 0
    }

    var headCell: GridPoint {
        cells.last ?? GridPoint(x: 0, y: 0)
    }

    var tailCell: GridPoint {
        cells.first ?? GridPoint(x: 0, y: 0)
    }

    var cellsSet: Set<GridPoint> { Set(cells) }
}
