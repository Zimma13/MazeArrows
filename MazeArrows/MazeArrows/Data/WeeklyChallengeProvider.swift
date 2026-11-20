//
//  WeeklyChallengeProvider.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Generates a deterministic hard puzzle keyed to the ISO week.
//  Same week → same puzzle for everyone.
//

import Foundation

actor WeeklyChallengeProvider {
    static let shared = WeeklyChallengeProvider()
    private init() {}

    private var cached: (week: String, level: Level)?

    nonisolated static func currentWeekString(now: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let year = components.yearForWeekOfYear ?? 2025
        let week = components.weekOfYear ?? 1
        return String(format: "%04d-W%02d", year, week)
    }

    func puzzle(for week: String) throws -> Level {
        try Task.checkCancellation()
        if let cached, cached.week == week { return cached.level }

        var rng = SeededRandomNumberGenerator(seed: seed(for: week))
        let config = DifficultyConfig.expert
        // Single call with a big budget — the generator relaxes its quality
        // gates in the back half, so this practically always succeeds.
        if let level = LevelGenerator.generate(config: config, index: 0, attempts: 200, rng: &rng) {
            try Task.checkCancellation()
            let weekly = Level(
                id: "weekly_\(week)",
                index: 0,
                difficulty: .expert,
                width: level.width,
                height: level.height,
                lives: level.lives,
                pieces: level.pieces,
                piecePalette: level.piecePalette,
                obstacles: level.obstacles,
                goal: level.goal,
                threeStarMaxMistakes: 0,
                twoStarMaxMistakes: 1,
                name: "Weekly · \(week)",
                rulesVersion: level.rulesVersion
            )
            cached = (week, weekly)
            return weekly
        }
        try Task.checkCancellation()

        // Self-contained fallback keeps this provider independent
        // from the asynchronously-loaded story catalog.
        let fallback = Level(
            id: "weekly_fallback_\(week)",
            index: 0,
            difficulty: .hard,
            width: 7,
            height: 9,
            lives: 3,
            pieces: [
                ArrowPiece(
                    id: "weekly_fallback_arrow",
                    cells: [GridPoint(x: 2, y: 4), GridPoint(x: 3, y: 4)],
                    direction: .right
                )
            ],
            name: "Weekly"
        )
        cached = (week, fallback)
        return fallback
    }

    private nonisolated func seed(for weekString: String) -> UInt64 {
        // Stable across launches — Swift's Hasher is per-process seeded.
        stableHash64("weekly_v1_" + weekString)
    }
}
