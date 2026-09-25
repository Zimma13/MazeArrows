//
//  Level.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

nonisolated struct Level: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let index: Int
    let difficulty: Difficulty
    let width: Int
    let height: Int
    let lives: Int
    let pieces: [ArrowPiece]
    /// Optional level-local colors. Photo levels use this to preserve source
    /// RGB values; an empty array falls back to the app's standard palette.
    let piecePalette: [PieceGroupPaletteColor]
    /// Field obstacles (walls, gates, portals, ice, springs, destructibles).
    /// Optional in JSON for backwards compatibility — defaults to empty.
    let obstacles: [Obstacle]
    /// Win condition. Defaults to `.clearAll`.
    let goal: LevelGoal
    /// Optional thresholds for the 3-star system. If nil, defaults are derived.
    let threeStarMaxMistakes: Int?
    let twoStarMaxMistakes: Int?
    /// Optional human-readable name shown in the win screen / level select.
    let name: String?

    init(
        id: String,
        index: Int,
        difficulty: Difficulty,
        width: Int,
        height: Int,
        lives: Int,
        pieces: [ArrowPiece],
        piecePalette: [PieceGroupPaletteColor] = [],
        obstacles: [Obstacle] = [],
        goal: LevelGoal = .clearAll,
        threeStarMaxMistakes: Int? = nil,
        twoStarMaxMistakes: Int? = nil,
        name: String? = nil
    ) {
        self.id = id
        self.index = index
        self.difficulty = difficulty
        self.width = width
        self.height = height
        self.lives = lives
        self.pieces = pieces
        self.piecePalette = piecePalette
        self.obstacles = obstacles
        self.goal = goal
        self.threeStarMaxMistakes = threeStarMaxMistakes
        self.twoStarMaxMistakes = twoStarMaxMistakes
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case id, index, difficulty, width, height, lives, pieces, piecePalette
        case obstacles, goal
        case threeStarMaxMistakes, twoStarMaxMistakes, name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        index = try c.decode(Int.self, forKey: .index)
        difficulty = try c.decode(Difficulty.self, forKey: .difficulty)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        lives = try c.decode(Int.self, forKey: .lives)
        pieces = try c.decode([ArrowPiece].self, forKey: .pieces)
        piecePalette = (try? c.decode([PieceGroupPaletteColor].self, forKey: .piecePalette)) ?? []
        obstacles = (try? c.decode([Obstacle].self, forKey: .obstacles)) ?? []
        goal = (try? c.decode(LevelGoal.self, forKey: .goal)) ?? .clearAll
        threeStarMaxMistakes = try? c.decode(Int.self, forKey: .threeStarMaxMistakes)
        twoStarMaxMistakes = try? c.decode(Int.self, forKey: .twoStarMaxMistakes)
        name = try? c.decode(String.self, forKey: .name)
    }

    func makeBoard() -> Board {
        Board(width: width, height: height, pieces: pieces, obstacles: obstacles)
    }

    /// Star count given `mistakes` made on this level.
    func stars(for mistakes: Int) -> Int {
        let perfect = threeStarMaxMistakes ?? 0
        let two = twoStarMaxMistakes ?? max(perfect + 1, 1)
        if mistakes <= perfect { return 3 }
        if mistakes <= two { return 2 }
        return 1
    }
}
