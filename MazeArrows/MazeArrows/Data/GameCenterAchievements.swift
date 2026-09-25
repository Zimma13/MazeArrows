//
//  GameCenterAchievements.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//  Stable achievement identifiers and point values shared by the app and
//  App Store Connect. Published identifiers and point values are permanent.
//

import Foundation

enum GameCenterAchievementID: String, CaseIterable, Codable, Sendable {
    case firstClear = "zimma.mazearrows.achievement.first_clear"
    case chapter1Complete = "zimma.mazearrows.achievement.chapter1_complete"
    case chapter2Complete = "zimma.mazearrows.achievement.chapter2_complete"
    case chapter3Complete = "zimma.mazearrows.achievement.chapter3_complete"
    case allLevelsComplete = "zimma.mazearrows.achievement.all_levels_complete"

    case perfectClear = "zimma.mazearrows.achievement.perfect_clear"
    case hintlessWin = "zimma.mazearrows.achievement.hintless_win"
    case speedrun = "zimma.mazearrows.achievement.speedrun"
    case comboMaster = "zimma.mazearrows.achievement.combo_master"
    case perfectChapter1 = "zimma.mazearrows.achievement.perfect_chapter1"

    case streak3 = "zimma.mazearrows.achievement.streak_3"
    case streak7 = "zimma.mazearrows.achievement.streak_7"

    case weeklyChampion = "zimma.mazearrows.achievement.weekly_champion"
    case questComplete = "zimma.mazearrows.achievement.quest_complete"
    case coinCollector = "zimma.mazearrows.achievement.coin_collector"

    var localID: AchievementID {
        switch self {
        case .firstClear: .firstClear
        case .chapter1Complete: .chapter1Complete
        case .chapter2Complete: .chapter2Complete
        case .chapter3Complete: .chapter3Complete
        case .allLevelsComplete: .allLevelsComplete
        case .perfectClear: .perfectClear
        case .hintlessWin: .hintlessWin
        case .speedrun: .speedrun
        case .comboMaster: .comboMaster
        case .perfectChapter1: .perfectChapter1
        case .streak3: .streak3
        case .streak7: .streak7
        case .weeklyChampion: .weeklyChampion
        case .questComplete: .questComplete
        case .coinCollector: .coinCollector
        }
    }

    var points: Int {
        switch self {
        case .firstClear: 10
        case .chapter1Complete: 40
        case .chapter2Complete: 50
        case .chapter3Complete: 60
        case .allLevelsComplete: 100
        case .perfectClear, .hintlessWin: 20
        case .speedrun: 30
        case .comboMaster: 40
        case .perfectChapter1: 75
        case .streak3: 25
        case .streak7: 50
        case .weeklyChampion: 40
        case .questComplete: 25
        case .coinCollector: 15
        }
    }

    /// Existing in-game achievements are visible goals and can only be earned once.
    var isHidden: Bool { false }
    var isRepeatable: Bool { false }

    static var totalPoints: Int {
        allCases.reduce(0) { $0 + $1.points }
    }

    init(localID: AchievementID) {
        switch localID {
        case .firstClear: self = .firstClear
        case .chapter1Complete: self = .chapter1Complete
        case .chapter2Complete: self = .chapter2Complete
        case .chapter3Complete: self = .chapter3Complete
        case .allLevelsComplete: self = .allLevelsComplete
        case .perfectClear: self = .perfectClear
        case .hintlessWin: self = .hintlessWin
        case .speedrun: self = .speedrun
        case .comboMaster: self = .comboMaster
        case .perfectChapter1: self = .perfectChapter1
        case .streak3: self = .streak3
        case .streak7: self = .streak7
        case .weeklyChampion: self = .weeklyChampion
        case .questComplete: self = .questComplete
        case .coinCollector: self = .coinCollector
        }
    }
}

struct GameCenterAchievementSnapshot: Equatable, Sendable {
    let earned: Set<GameCenterAchievementID>

    init(earnedAchievements: Set<AchievementID>) {
        earned = Set(earnedAchievements.map(GameCenterAchievementID.init(localID:)))
    }
}
