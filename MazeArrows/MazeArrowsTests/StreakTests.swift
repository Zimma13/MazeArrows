//
//  StreakTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

@MainActor
struct StreakFreezeTests {

    /// Config with no chest noise so coin assertions stay simple.
    private var config: EconomyConfig {
        var config = EconomyConfig.default
        config.streakChests = [:]
        return config
    }

    private func makeStore() -> ProgressStore {
        let name = "MazeArrowsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ProgressStore(defaults: defaults)
    }

    private func makeLevel() -> Level {
        Level(
            id: "daily-test",
            index: 0,
            difficulty: .easy,
            width: 4,
            height: 4,
            lives: 5,
            pieces: [
                ArrowPiece(id: "a", cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)], direction: .left)
            ]
        )
    }

    private func complete(_ store: ProgressStore, on date: String, config: EconomyConfig) {
        store.recordDailyCompletion(date: date, mistakesCount: 0, level: makeLevel(), config: config)
    }

    @Test func consecutiveDaysGrowStreakWithoutTouchingFreezes() {
        let store = makeStore()
        store.progress.streakFreezes = 1

        complete(store, on: "2026-08-01", config: config)
        complete(store, on: "2026-08-02", config: config)

        #expect(store.progress.dailyStreak == 2)
        #expect(store.progress.bestDailyStreak == 2)
        #expect(store.progress.streakFreezes == 1)
    }

    @Test func freezeCoversExactlyOneMissedDay() {
        let store = makeStore()
        store.progress.streakFreezes = 1

        complete(store, on: "2026-08-01", config: config)
        complete(store, on: "2026-08-02", config: config)
        // 2026-08-03 missed.
        complete(store, on: "2026-08-04", config: config)

        #expect(store.progress.dailyStreak == 3)
        #expect(store.progress.streakFreezes == 0)
    }

    @Test func missedDayWithoutFreezeResetsStreak() {
        let store = makeStore()

        complete(store, on: "2026-08-01", config: config)
        complete(store, on: "2026-08-02", config: config)
        complete(store, on: "2026-08-04", config: config)

        #expect(store.progress.dailyStreak == 1)
        #expect(store.progress.bestDailyStreak == 2)
    }

    @Test func freezeDoesNotCoverTwoMissedDays() {
        let store = makeStore()
        store.progress.streakFreezes = 2

        complete(store, on: "2026-08-01", config: config)
        // 2026-08-02 and 2026-08-03 missed — freezes must stay untouched.
        complete(store, on: "2026-08-04", config: config)

        #expect(store.progress.dailyStreak == 1)
        #expect(store.progress.streakFreezes == 2)
    }

    @Test func repeatCompletionSameDayChangesNothing() {
        let store = makeStore()
        store.progress.streakFreezes = 1

        complete(store, on: "2026-08-01", config: config)
        complete(store, on: "2026-08-01", config: config)

        #expect(store.progress.dailyStreak == 1)
        #expect(store.progress.streakFreezes == 1)
    }
}

@MainActor
struct StreakChestTests {

    private func makeStore() -> ProgressStore {
        let name = "MazeArrowsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ProgressStore(defaults: defaults)
    }

    private func makeLevel() -> Level {
        Level(
            id: "daily-test",
            index: 0,
            difficulty: .easy,
            width: 4,
            height: 4,
            lives: 5,
            pieces: [
                ArrowPiece(id: "a", cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)], direction: .left)
            ],
            // Force 1-star days: a fixed 25-coin daily reward keeps math simple.
            threeStarMaxMistakes: -1,
            twoStarMaxMistakes: -1
        )
    }

    private func complete(_ store: ProgressStore, on date: String, config: EconomyConfig) {
        store.recordDailyCompletion(date: date, mistakesCount: 0, level: makeLevel(), config: config)
    }

    @Test func chestGrantsOnceAtThreshold() {
        var config = EconomyConfig.default
        config.streakChests = [2: 50]
        let store = makeStore()

        complete(store, on: "2026-08-01", config: config)
        #expect(store.progress.coins == 25)                 // daily only
        #expect(store.progress.claimedStreakChests.isEmpty)

        complete(store, on: "2026-08-02", config: config)
        #expect(store.progress.dailyStreak == 2)
        #expect(store.progress.coins == 25 + 25 + 50)       // + chest
        #expect(store.progress.claimedStreakChests == [2])

        // Day 3 keeps the streak above the threshold — no double grant.
        // (Streak 3 also unlocks the streak3 achievement: +50.)
        complete(store, on: "2026-08-03", config: config)
        #expect(store.progress.coins == 25 * 3 + 50 + 50)
        #expect(store.progress.claimedStreakChests == [2])
    }

    @Test func chestNotGrantedAgainAfterStreakRebuild() {
        var config = EconomyConfig.default
        config.streakChests = [2: 50]
        let store = makeStore()

        complete(store, on: "2026-08-01", config: config)
        complete(store, on: "2026-08-02", config: config)   // chest claimed
        complete(store, on: "2026-08-10", config: config)   // break → streak 1
        complete(store, on: "2026-08-11", config: config)   // rebuilt to 2

        #expect(store.progress.dailyStreak == 2)
        #expect(store.progress.claimedStreakChests == [2])
        #expect(store.progress.coins == 25 * 4 + 50)        // chest paid once
    }

    @Test func longStreakCollectsEveryChest() {
        var config = EconomyConfig.default
        config.streakChests = [1: 10, 2: 20, 3: 30]
        let store = makeStore()

        complete(store, on: "2026-08-01", config: config)
        complete(store, on: "2026-08-02", config: config)
        complete(store, on: "2026-08-03", config: config)

        #expect(store.progress.claimedStreakChests == [1, 2, 3])
        // 3 dailies + all chests + streak3 achievement (+50).
        #expect(store.progress.coins == 25 * 3 + 10 + 20 + 30 + 50)
    }

    @Test func lateThresholdClaimedTheDayStreakReachesIt() {
        var config = EconomyConfig.default
        config.streakChests = [3: 100]
        let store = makeStore()
        store.progress.streakFreezes = 1

        complete(store, on: "2026-08-01", config: config)
        complete(store, on: "2026-08-02", config: config)
        // Missed day covered by a freeze — the streak still reaches 3.
        complete(store, on: "2026-08-04", config: config)

        #expect(store.progress.dailyStreak == 3)
        #expect(store.progress.claimedStreakChests == [3])
        // 75 daily + 100 chest + 50 streak3 achievement crosses 200 coins,
        // which unlocks coinCollector for another +50.
        #expect(store.progress.coins == 25 * 3 + 100 + 50 + 50)
    }
}
