//
//  PlayerProgress.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

struct PlayerProgress: Codable, Sendable {
    var unlockedLevelIndex: Int
    var completedLevels: Set<Int>
    var hintsCount: Int                     // Legacy inventory, preserved across updates.
    var undosCount: Int
    var stars: [Int: Int]                    // levelIndex → best stars (0..3)
    var bestTimes: [Int: Int]                // levelIndex → best time in seconds
    var dailyStreak: Int
    var bestDailyStreak: Int                 // all-time maximum, never decreases
    var lastDailyCompletionDate: String?     // yyyy-MM-dd, UTC
    var dailyCompletions: Set<String>         // rewarded UTC dates
    var coins: Int

    // Achievements
    var earnedAchievements: Set<AchievementID>

    // Weekly challenges  ("YYYY-Www" → completed)
    var weeklyCompletions: Set<String>

    // Daily quests
    var dailyQuestState: DailyQuestState

    // Economy
    var streakFreezes: Int
    var claimedStreakChests: Set<Int>        // streak-day milestones already paid

    // Position in the daily sequence of Zen boards.
    var zenPlayedDate: String?               // yyyy-MM-dd, UTC
    var zenPlayedCount: Int

    // Master layer: levelIndex → modifiers cleared
    var masterClears: [Int: Set<GameMode>]

    // Historical Photo Maze counts retained for save compatibility.
    var photoMazeFreeGenerationsUsed: Int
    var photoMazeRewardedCredits: Int

    static let initial = PlayerProgress(
        unlockedLevelIndex: 1,
        completedLevels: [],
        hintsCount: 3,
        undosCount: 5,
        stars: [:],
        bestTimes: [:],
        dailyStreak: 0,
        bestDailyStreak: 0,
        lastDailyCompletionDate: nil,
        dailyCompletions: [],
        coins: 0,
        earnedAchievements: [],
        weeklyCompletions: [],
        dailyQuestState: .empty,
        streakFreezes: 0,
        claimedStreakChests: [],
        zenPlayedDate: nil,
        zenPlayedCount: 0,
        masterClears: [:],
        photoMazeFreeGenerationsUsed: 0,
        photoMazeRewardedCredits: 0
    )

    enum CodingKeys: String, CodingKey {
        case unlockedLevelIndex, completedLevels, hintsCount, undosCount
        case stars, bestTimes, dailyStreak, bestDailyStreak
        case lastDailyCompletionDate, dailyCompletions, coins
        case earnedAchievements, weeklyCompletions, dailyQuestState
        case streakFreezes, claimedStreakChests, zenPlayedDate, zenPlayedCount, masterClears
        case photoMazeFreeGenerationsUsed, photoMazeRewardedCredits
    }

    init(
        unlockedLevelIndex: Int,
        completedLevels: Set<Int>,
        hintsCount: Int,
        undosCount: Int,
        stars: [Int: Int],
        bestTimes: [Int: Int] = [:],
        dailyStreak: Int,
        bestDailyStreak: Int = 0,
        lastDailyCompletionDate: String?,
        dailyCompletions: Set<String> = [],
        coins: Int,
        earnedAchievements: Set<AchievementID> = [],
        weeklyCompletions: Set<String> = [],
        dailyQuestState: DailyQuestState = .empty,
        streakFreezes: Int = 0,
        claimedStreakChests: Set<Int> = [],
        zenPlayedDate: String? = nil,
        zenPlayedCount: Int = 0,
        masterClears: [Int: Set<GameMode>] = [:],
        photoMazeFreeGenerationsUsed: Int = 0,
        photoMazeRewardedCredits: Int = 0
    ) {
        self.unlockedLevelIndex = max(1, unlockedLevelIndex)
        self.completedLevels = Set(completedLevels.filter { $0 > 0 })
        self.hintsCount = hintsCount
        self.undosCount = undosCount
        self.stars = stars.filter { $0.key > 0 }
        self.bestTimes = bestTimes.filter { $0.key > 0 }
        self.dailyStreak = dailyStreak
        self.bestDailyStreak = max(bestDailyStreak, dailyStreak)
        self.lastDailyCompletionDate = lastDailyCompletionDate
        self.dailyCompletions = dailyCompletions
        if let lastDailyCompletionDate {
            self.dailyCompletions.insert(lastDailyCompletionDate)
        }
        self.coins = coins
        self.earnedAchievements = earnedAchievements
        self.weeklyCompletions = weeklyCompletions
        self.dailyQuestState = dailyQuestState
        self.streakFreezes = streakFreezes
        self.claimedStreakChests = claimedStreakChests
        self.zenPlayedDate = zenPlayedDate
        self.zenPlayedCount = zenPlayedCount
        self.masterClears = masterClears.filter { $0.key > 0 }
        self.photoMazeFreeGenerationsUsed = max(0, photoMazeFreeGenerationsUsed)
        self.photoMazeRewardedCredits = max(0, photoMazeRewardedCredits)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unlockedLevelIndex = max(1, try c.decode(Int.self, forKey: .unlockedLevelIndex))
        completedLevels = Set(
            try c.decode(Set<Int>.self, forKey: .completedLevels).filter { $0 > 0 }
        )
        hintsCount = try c.decode(Int.self, forKey: .hintsCount)
        undosCount = try c.decode(Int.self, forKey: .undosCount)
        stars = try c.decode([Int: Int].self, forKey: .stars).filter { $0.key > 0 }
        bestTimes = ((try? c.decode([Int: Int].self, forKey: .bestTimes)) ?? [:])
            .filter { $0.key > 0 }
        dailyStreak = try c.decode(Int.self, forKey: .dailyStreak)
        bestDailyStreak = max(
            (try? c.decode(Int.self, forKey: .bestDailyStreak)) ?? 0,
            dailyStreak
        )
        lastDailyCompletionDate = try? c.decode(String.self, forKey: .lastDailyCompletionDate)
        dailyCompletions = (try? c.decode(Set<String>.self, forKey: .dailyCompletions)) ?? []
        if let lastDailyCompletionDate {
            dailyCompletions.insert(lastDailyCompletionDate)
        }
        coins = try c.decode(Int.self, forKey: .coins)
        earnedAchievements = (try? c.decode(Set<AchievementID>.self, forKey: .earnedAchievements)) ?? []
        weeklyCompletions = (try? c.decode(Set<String>.self, forKey: .weeklyCompletions)) ?? []
        dailyQuestState = (try? c.decode(DailyQuestState.self, forKey: .dailyQuestState)) ?? .empty
        streakFreezes = (try? c.decode(Int.self, forKey: .streakFreezes)) ?? 0
        claimedStreakChests = (try? c.decode(Set<Int>.self, forKey: .claimedStreakChests)) ?? []
        bestDailyStreak = max(bestDailyStreak, claimedStreakChests.max() ?? 0)
        zenPlayedDate = try? c.decode(String.self, forKey: .zenPlayedDate)
        zenPlayedCount = (try? c.decode(Int.self, forKey: .zenPlayedCount)) ?? 0
        masterClears = ((try? c.decode([Int: Set<GameMode>].self, forKey: .masterClears)) ?? [:])
            .filter { $0.key > 0 }
        photoMazeFreeGenerationsUsed = max(
            0,
            (try? c.decode(Int.self, forKey: .photoMazeFreeGenerationsUsed)) ?? 0
        )
        photoMazeRewardedCredits = max(
            0,
            (try? c.decode(Int.self, forKey: .photoMazeRewardedCredits)) ?? 0
        )
    }

    @discardableResult
    mutating func mark(levelIndex: Int, stars: Int) -> Int {
        guard levelIndex > 0 else { return 0 }
        let previousBest = self.stars[levelIndex] ?? 0
        completedLevels.insert(levelIndex)
        let best = max(previousBest, stars)
        self.stars[levelIndex] = best
        unlockedLevelIndex = max(unlockedLevelIndex, levelIndex + 1)
        return best - previousBest
    }

    mutating func recordBestTime(levelIndex: Int, seconds: Int) {
        guard levelIndex > 0 else { return }
        let current = bestTimes[levelIndex] ?? Int.max
        if seconds > 0 && seconds < current {
            bestTimes[levelIndex] = seconds
        }
    }

    func isUnlocked(_ levelIndex: Int) -> Bool {
        levelIndex <= unlockedLevelIndex
    }

    func bestStars(_ levelIndex: Int) -> Int { stars[levelIndex] ?? 0 }
    func bestTime(_ levelIndex: Int) -> Int? { bestTimes[levelIndex] }

    func hasEarned(_ id: AchievementID) -> Bool { earnedAchievements.contains(id) }

    mutating func claimDailyCompletion(_ date: String) -> Bool {
        dailyCompletions.insert(date).inserted
    }

    mutating func earn(_ id: AchievementID) {
        earnedAchievements.insert(id)
    }

    func hasCompletedWeekly(_ week: String) -> Bool { weeklyCompletions.contains(week) }
}
