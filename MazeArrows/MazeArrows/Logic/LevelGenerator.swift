//
//  LevelGenerator.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Builds levels with the snake-fill generator: the whole board is covered by
//  winding arrow pieces and directions are assigned so the level is solvable
//  by construction. Difficulty gating is done on measured metrics (initially
//  movable arrows, dependency depth) rather than density heuristics.
//

import Foundation

nonisolated enum LevelGenerator {

    /// Generates a single level matching `config`. May fail and return nil if
    /// no arrangement passed the quality gates within `attempts` tries;
    /// caller may retry or fall back to handcrafted levels.
    static func generate<G: RandomNumberGenerator>(
        config: DifficultyConfig,
        index: Int,
        attempts: Int = 30,
        rng: inout G
    ) -> Level? {
        guard !Task.isCancelled else { return nil }
        var mask = Set<GridPoint>()
        for y in 0..<config.height {
            guard !Task.isCancelled else { return nil }
            for x in 0..<config.width {
                mask.insert(GridPoint(x: x, y: y))
            }
        }

        for attempt in 0..<attempts {
            guard !Task.isCancelled else { return nil }
            // Past the halfway mark, progressively relax the quality gates so
            // a caller with a fixed seed (daily/weekly) always gets a level.
            let relax = max(0, attempt - attempts / 2)
            let movableCap = config.maxInitialMovable + relax / 10
            let depthFloor = max(2, config.minParallelDepth - relax / 5)

            guard let pieces = SnakeFillGenerator.makePieces(
                mask: mask,
                boardWidth: config.width,
                boardHeight: config.height,
                config: config.snakeFill,
                idPrefix: "g\(index)",
                rng: &rng
            ) else { continue }
            guard !Task.isCancelled else { return nil }

            let board = Board(width: config.width, height: config.height, pieces: pieces)
            let metrics = LevelMetrics.evaluate(board: board)
            guard !Task.isCancelled else { return nil }

            guard metrics.initialMovable >= 1 else { continue }
            guard metrics.initialMovable <= movableCap else { continue }
            guard metrics.parallelDepth >= depthFloor else { continue }
            // Reject boards dominated by long straight strips — they read as
            // easy even when the dependency structure isn't.
            guard metrics.dullRatio <= 0.15 + Double(relax) * 0.002 else { continue }
            // Defensive re-check; peeling guarantees this holds.
            guard LevelSolver.solve(board: board) != nil else { continue }
            guard !Task.isCancelled else { return nil }

            return Level(
                id: "gen_\(config.difficulty.rawValue)_\(index)",
                index: index,
                difficulty: config.difficulty,
                width: config.width,
                height: config.height,
                lives: config.lives,
                pieces: pieces,
                threeStarMaxMistakes: 0,
                twoStarMaxMistakes: max(1, pieces.count / 6),
                name: nil
            )
        }
        return nil
    }
}
