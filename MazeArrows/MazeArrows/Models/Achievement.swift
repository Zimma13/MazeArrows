//
//  Achievement.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

enum AchievementID: String, Codable, CaseIterable, Sendable {
    // Progress
    case firstClear        = "first_clear"
    case chapter1Complete  = "chapter1_complete"
    case chapter2Complete  = "chapter2_complete"
    case chapter3Complete  = "chapter3_complete"
    case allLevelsComplete = "all_levels_complete"

    // Skill
    case perfectClear      = "perfect_clear"
    case hintlessWin       = "hintless_win"
    case speedrun          = "speedrun"
    case comboMaster       = "combo_master"
    case perfectChapter1   = "perfect_chapter1"

    // Streak
    case streak3           = "streak_3"
    case streak7           = "streak_7"

    // Special
    case weeklyChampion    = "weekly_champion"
    case questComplete     = "quest_complete"
    case coinCollector     = "coin_collector"
}

struct Achievement: Identifiable, Sendable {
    let id: AchievementID
    let icon: String
    let category: Category

    var imageAssetName: String {
        "achievement_\(id.rawValue)"
    }

    enum Category: String, Sendable {
        case progress
        case skill
        case streak
        case special

        var displayName: String {
            switch self {
            case .progress: return String(localized: "Progress")
            case .skill:    return String(localized: "Skill")
            case .streak:   return String(localized: "Streak")
            case .special:  return String(localized: "Special")
            }
        }
    }

    var title: String {
        switch id {
        case .firstClear:        return String(localized: "First Steps")
        case .chapter1Complete:  return String(localized: "Meadow Wanderer")
        case .chapter2Complete:  return String(localized: "Forest Explorer")
        case .chapter3Complete:  return String(localized: "Summit Seeker")
        case .allLevelsComplete: return String(localized: "Pathfinder")
        case .perfectClear:      return String(localized: "Perfectionist")
        case .hintlessWin:       return String(localized: "Purist")
        case .speedrun:          return String(localized: "Speed Demon")
        case .comboMaster:       return String(localized: "Combo Master")
        case .perfectChapter1:   return String(localized: "Flawless Meadow")
        case .streak3:           return String(localized: "On a Roll")
        case .streak7:           return String(localized: "Dedicated")
        case .weeklyChampion:    return String(localized: "Weekly Champion")
        case .questComplete:     return String(localized: "Quest Finisher")
        case .coinCollector:     return String(localized: "Coin Collector")
        }
    }

    var description: String {
        switch id {
        case .firstClear:        return String(localized: "Complete your first level")
        case .chapter1Complete:  return String(localized: "Complete all levels in The Meadows")
        case .chapter2Complete:  return String(localized: "Complete all levels in The Forest")
        case .chapter3Complete:  return String(localized: "Complete all levels in The Mountains")
        case .allLevelsComplete: return String(localized: "Complete all 240 levels")
        case .perfectClear:      return String(localized: "Earn 3 stars on any level")
        case .hintlessWin:       return String(localized: "Complete a level without using any hints")
        case .speedrun:          return String(localized: "Complete a level in under 60 seconds")
        case .comboMaster:       return String(localized: "Achieve a 5× combo in a single level")
        case .perfectChapter1:   return String(localized: "Earn 3 stars on every level in The Meadows")
        case .streak3:           return String(localized: "Complete the Daily puzzle 3 days in a row")
        case .streak7:           return String(localized: "Complete the Daily puzzle 7 days in a row")
        case .weeklyChampion:    return String(localized: "Complete a Weekly Challenge")
        case .questComplete:     return String(localized: "Complete all 3 Daily Quests in one day")
        case .coinCollector:     return String(localized: "Accumulate 200 coins")
        }
    }

    static let all: [Achievement] = [
        // Progress
        Achievement(id: .firstClear,        icon: "flag.fill",                  category: .progress),
        Achievement(id: .chapter1Complete,  icon: "leaf.fill",                  category: .progress),
        Achievement(id: .chapter2Complete,  icon: "tree.fill",                  category: .progress),
        Achievement(id: .chapter3Complete,  icon: "mountain.2.fill",            category: .progress),
        Achievement(id: .allLevelsComplete, icon: "map.fill",                   category: .progress),

        // Skill
        Achievement(id: .perfectClear,      icon: "star.fill",                  category: .skill),
        Achievement(id: .hintlessWin,       icon: "eye.slash.fill",             category: .skill),
        Achievement(id: .speedrun,          icon: "bolt.fill",                  category: .skill),
        Achievement(id: .comboMaster,       icon: "flame.fill",                 category: .skill),
        Achievement(id: .perfectChapter1,   icon: "sparkles",                   category: .skill),

        // Streak
        Achievement(id: .streak3,           icon: "calendar.badge.clock",       category: .streak),
        Achievement(id: .streak7,           icon: "calendar.badge.checkmark",   category: .streak),

        // Special
        Achievement(id: .weeklyChampion,    icon: "trophy.fill",                category: .special),
        Achievement(id: .questComplete,     icon: "checkmark.seal.fill",        category: .special),
        Achievement(id: .coinCollector,     icon: "circle.fill",                category: .special),
    ]

    static func find(_ id: AchievementID) -> Achievement? {
        all.first { $0.id == id }
    }
}
