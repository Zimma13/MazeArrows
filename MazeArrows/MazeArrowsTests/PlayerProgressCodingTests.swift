//
//  PlayerProgressCodingTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

@MainActor
struct PlayerProgressCodingTests {

    /// A payload saved before the economy fields existed must decode with
    /// safe defaults — players keep their progress after the update.
    @Test func legacyPayloadDecodesWithEconomyDefaults() throws {
        let legacy = """
        {
            "unlockedLevelIndex": 5,
            "completedLevels": [1, 2, 3, 4],
            "hintsCount": 2,
            "undosCount": 4,
            "stars": {"1": 3, "2": 2},
            "dailyStreak": 2,
            "coins": 75
        }
        """
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: Data(legacy.utf8))

        #expect(decoded.coins == 75)
        #expect(decoded.unlockedLevelIndex == 5)
        #expect(decoded.bestDailyStreak == 2)
        #expect(decoded.streakFreezes == 0)
        #expect(decoded.claimedStreakChests.isEmpty)
        #expect(decoded.zenPlayedDate == nil)
        #expect(decoded.zenPlayedCount == 0)
        #expect(decoded.masterClears.isEmpty)
        #expect(decoded.photoMazeFreeGenerationsUsed == 0)
        #expect(decoded.photoMazeRewardedCredits == 0)
    }

    @Test func roundTripPreservesEconomyFields() throws {
        var progress = PlayerProgress.initial
        progress.coins = 320
        progress.streakFreezes = 2
        progress.bestDailyStreak = 11
        progress.claimedStreakChests = [3, 7]
        progress.zenPlayedDate = "2026-08-05"
        progress.zenPlayedCount = 3
        progress.masterClears = [12: [.hard, .timed], 40: [.challenge]]
        progress.photoMazeFreeGenerationsUsed = 5
        progress.photoMazeRewardedCredits = 2

        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: data)

        #expect(decoded.coins == 320)
        #expect(decoded.streakFreezes == 2)
        #expect(decoded.bestDailyStreak == 11)
        #expect(decoded.claimedStreakChests == [3, 7])
        #expect(decoded.zenPlayedDate == "2026-08-05")
        #expect(decoded.zenPlayedCount == 3)
        #expect(decoded.masterClears == [12: [.hard, .timed], 40: [.challenge]])
        #expect(decoded.photoMazeFreeGenerationsUsed == 5)
        #expect(decoded.photoMazeRewardedCredits == 2)
    }

    @Test func oldSaveContinuesZenAfterThirdBoardWithLegacyInventoryIntact() {
        let defaults = UserDefaults(suiteName: "PaidEditionTests.\(UUID().uuidString)")!
        let date = "2026-08-05"
        let old = """
        {"unlockedLevelIndex":6,"completedLevels":[1,2,3,4,5],"stars":{"5":2},
         "hintsCount":7,"undosCount":8,"dailyStreak":2,"coins":91,
         "zenPlayedDate":"2026-08-05","zenPlayedCount":3,
         "photoMazeFreeGenerationsUsed":5,"photoMazeRewardedCredits":2}
        """
        defaults.set(Data(old.utf8), forKey: "MazeArrows.PlayerProgress.v2")
        let store = ProgressStore(defaults: defaults)
        #expect(store.nextZenIndex(date: date) == 3)
        store.recordZenCompletion(date: date, index: 3)

        let saved = ProgressStore(defaults: defaults).progress
        #expect(saved.zenPlayedCount == 4)
        #expect(saved.unlockedLevelIndex == 6)
        #expect(saved.bestStars(5) == 2)
        #expect(saved.coins == 91)
        #expect(saved.hintsCount == 7)
        #expect(saved.undosCount == 8)
        #expect(saved.photoMazeFreeGenerationsUsed == 5)
        #expect(saved.photoMazeRewardedCredits == 2)
    }

    @Test func memberwiseInitDropsNonPositiveMasterClearKeys() {
        let progress = PlayerProgress(
            unlockedLevelIndex: 1,
            completedLevels: [],
            hintsCount: 3,
            undosCount: 5,
            stars: [:],
            dailyStreak: 0,
            lastDailyCompletionDate: nil,
            coins: 0,
            masterClears: [0: [.hard], -1: [.timed], 7: [.challenge]]
        )
        #expect(progress.masterClears == [7: [.challenge]])
    }
}
