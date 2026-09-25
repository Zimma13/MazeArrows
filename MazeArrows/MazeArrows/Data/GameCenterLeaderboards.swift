//
//  GameCenterLeaderboards.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Stable identifiers shared by the app and App Store Connect. Do not rename
//  an identifier after its leaderboard has been created in App Store Connect.
//

import Foundation

enum GameCenterLeaderboardID: String, CaseIterable, Codable, Sendable {
    case campaignLevelsCompleted = "zimma.mazearrows.campaign_levels_completed"
    case masterCrowns = "zimma.mazearrows.master_crowns"
    case longestDailyStreak = "zimma.mazearrows.longest_daily_streak"
}

/// A compact, stable view of local progress suitable for Game Center.
/// Every score is monotonic and uses a higher-is-better leaderboard.
struct GameCenterLeaderboardSnapshot: Equatable, Sendable {
    let campaignLevelsCompleted: Int
    let masterCrowns: Int
    let longestDailyStreak: Int

    init(progress: PlayerProgress) {
        campaignLevelsCompleted = progress.completedLevels.lazy
            .filter { $0 > 0 }
            .count

        let validModifiers = Set(GameMode.masterModifiers)
        masterCrowns = progress.masterClears.values.reduce(into: 0) { total, clears in
            total += clears.intersection(validModifiers).count
        }

        longestDailyStreak = max(progress.dailyStreak, progress.bestDailyStreak)
    }

    var scores: [GameCenterLeaderboardID: Int] {
        [
            .campaignLevelsCompleted: campaignLevelsCompleted,
            .masterCrowns: masterCrowns,
            .longestDailyStreak: longestDailyStreak
        ]
    }
}
