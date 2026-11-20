//
//  DailyPuzzleProvider.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Generates a deterministic medium-sized puzzle keyed to the calendar day.
//  Same date → same puzzle for everyone. Cached in memory for the session.
//

import Foundation

actor DailyPuzzleProvider {
    static let shared = DailyPuzzleProvider()
    private init() {}

    private var cached: (date: String, level: Level)?

    nonisolated static func todayDateString(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: now)
    }

    func puzzle(for date: String) throws -> Level {
        try Task.checkCancellation()
        if let cached, cached.date == date { return cached.level }

        var rng = SeededRandomNumberGenerator(seed: seed(for: date))
        let config = DifficultyConfig.medium
        // Single call with a big budget — the generator relaxes its quality
        // gates in the back half, so this practically always succeeds.
        if let level = LevelGenerator.generate(config: config, index: 0, attempts: 120, rng: &rng) {
            try Task.checkCancellation()
            let daily = Level(
                id: "daily_\(date)",
                index: 0,
                difficulty: .medium,
                width: level.width,
                height: level.height,
                lives: level.lives,
                pieces: level.pieces,
                piecePalette: level.piecePalette,
                obstacles: level.obstacles,
                goal: level.goal,
                threeStarMaxMistakes: 0,
                twoStarMaxMistakes: 1,
                name: "Daily · \(date)",
                rulesVersion: level.rulesVersion
            )
            cached = (date, daily)
            return daily
        }
        try Task.checkCancellation()

        // Hard fallback — should never trip, but keeps the API total.
        let fallback = Level(
            id: "daily_fallback_\(date)",
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
            threeStarMaxMistakes: 0,
            twoStarMaxMistakes: 1,
            name: "Daily"
        )
        cached = (date, fallback)
        return fallback
    }

    private nonisolated func seed(for dateString: String) -> UInt64 {
        // Swift's Hasher is randomly seeded per process — it would give a
        // different "daily" puzzle on every launch. FNV-1a is stable.
        stableHash64(dateString)
    }
}
