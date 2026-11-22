//
//  ZenProvider.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Deterministic endless Zen levels: same UTC day + position → same board on
//  every device. Difficulty ramps gently within a day and settles at hard.
//  Zen levels never grant rewards — see GameViewModel.recordCompletion.
//

import Foundation

actor ZenProvider {
    static let shared = ZenProvider()
    private init() {}

    private var lastBoard: (key: String, level: Level)?

    nonisolated static func difficulty(forIndex index: Int) -> Difficulty {
        switch index {
        case 0:     return .easy
        case 1, 2:  return .medium
        default:    return .hard
        }
    }

    func level(date: String, index: Int) throws -> Level {
        try Task.checkCancellation()
        let key = "zen_\(date)_\(index)"
        if let lastBoard, lastBoard.key == key { return lastBoard.level }

        let difficulty = Self.difficulty(forIndex: index)
        var rng = SeededRandomNumberGenerator(seed: stableHash64(key))
        let config = DifficultyConfig.config(for: difficulty)
        if let generated = LevelGenerator.generate(config: config, index: 0, attempts: 120, rng: &rng) {
            try Task.checkCancellation()
            let zen = Level(
                id: key,
                index: 0,
                difficulty: difficulty,
                width: generated.width,
                height: generated.height,
                lives: generated.lives,
                pieces: generated.pieces,
                piecePalette: generated.piecePalette,
                obstacles: generated.obstacles,
                goal: generated.goal,
                name: "Zen · \(index + 1)",
                rulesVersion: generated.rulesVersion
            )
            lastBoard = (key, zen)
            return zen
        }
        try Task.checkCancellation()

        // Hard fallback — should never trip, but keeps the API total.
        let fallback = Level(
            id: "\(key)_fallback",
            index: 0,
            difficulty: .easy,
            width: 7,
            height: 9,
            lives: 5,
            pieces: [
                ArrowPiece(
                    id: "fallback_arrow",
                    cells: [GridPoint(x: 2, y: 4), GridPoint(x: 3, y: 4)],
                    direction: .right
                )
            ],
            name: "Zen"
        )
        lastBoard = (key, fallback)
        return fallback
    }
}
