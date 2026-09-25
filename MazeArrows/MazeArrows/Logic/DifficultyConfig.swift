//
//  DifficultyConfig.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Tuning knobs for the snake-fill generator. Boards are filled to 100%
//  density (every cell belongs to some arrow, like the reference puzzles);
//  difficulty comes from board size, snake length/winding, and how deep the
//  dependency chains go.
//

import Foundation

nonisolated struct DifficultyConfig: Sendable {
    let difficulty: Difficulty
    let width: Int
    let height: Int
    /// Snake body length bounds, in cells.
    let snakeMinLength: Int
    let snakeMaxLength: Int
    /// 0...1 — tendency of snakes to keep going straight while growing.
    let straightBias: Double
    /// 0...1 — how aggressively directions are chained (see SnakeFillConfig).
    let chainBias: Double
    /// Quality gates measured on the generated board.
    let maxInitialMovable: Int
    let minParallelDepth: Int
    let lives: Int

    var snakeFill: SnakeFillConfig {
        SnakeFillConfig(
            minLength: snakeMinLength,
            maxLength: snakeMaxLength,
            straightBias: straightBias,
            chainBias: chainBias
        )
    }

    static let easy = DifficultyConfig(
        difficulty: .easy,
        width: 12, height: 16,
        snakeMinLength: 4, snakeMaxLength: 10,
        straightBias: 0.55,
        chainBias: 0.7,
        maxInitialMovable: 4,
        minParallelDepth: 8,
        lives: 5
    )

    static let medium = DifficultyConfig(
        difficulty: .medium,
        width: 15, height: 21,
        snakeMinLength: 4, snakeMaxLength: 11,
        straightBias: 0.50,
        chainBias: 0.85,
        maxInitialMovable: 3,
        minParallelDepth: 13,
        lives: 5
    )

    static let hard = DifficultyConfig(
        difficulty: .hard,
        width: 20, height: 28,
        snakeMinLength: 4, snakeMaxLength: 12,
        straightBias: 0.46,
        chainBias: 0.95,
        maxInitialMovable: 9,
        minParallelDepth: 13,
        lives: 3
    )

    static let expert = DifficultyConfig(
        difficulty: .expert,
        width: 26, height: 36,
        snakeMinLength: 4, snakeMaxLength: 13,
        straightBias: 0.42,
        chainBias: 0.98,
        maxInitialMovable: 12,
        minParallelDepth: 15,
        lives: 3
    )

    static func config(for difficulty: Difficulty) -> DifficultyConfig {
        switch difficulty {
        case .easy:   return .easy
        case .medium: return .medium
        case .hard:   return .hard
        case .expert: return .expert
        }
    }
}
