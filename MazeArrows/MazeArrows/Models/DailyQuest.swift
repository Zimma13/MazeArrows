//
//  DailyQuest.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

enum QuestType: String, Codable, Sendable {
    case completeLevels   // finish N story levels
    case perfectClears    // earn 3 stars on N levels
    case hintlessClears   // finish N levels using zero hints
    case solveDailyPuzzle // complete today's daily puzzle
}

/// The quest catalog. Persisted state stores only the template id, so titles
/// and descriptions follow the current app language instead of freezing at
/// whatever language generated the quest.
enum QuestTemplateID: String, Codable, Sendable, CaseIterable {
    case levelUp
    case starHunter
    case pureFocus
    case dailyPilgrim
    case bingeSolver
    case perfectionist
    case zenMaster

    var title: String {
        switch self {
        case .levelUp:      return String(localized: "Level Up")
        case .starHunter:   return String(localized: "Star Hunter")
        case .pureFocus:    return String(localized: "Pure Focus")
        case .dailyPilgrim: return String(localized: "Daily Pilgrim")
        case .bingeSolver:  return String(localized: "Binge Solver")
        case .perfectionist: return String(localized: "Perfectionist")
        case .zenMaster:    return String(localized: "Zen Master")
        }
    }

    var details: String {
        switch self {
        case .levelUp:      return String(localized: "Complete 3 story levels")
        case .starHunter:   return String(localized: "Earn 3 stars on 2 levels")
        case .pureFocus:    return String(localized: "Complete a level without hints")
        case .dailyPilgrim: return String(localized: "Solve today's Daily puzzle")
        case .bingeSolver:  return String(localized: "Complete 5 story levels")
        case .perfectionist: return String(localized: "Earn 3 stars on 3 levels")
        case .zenMaster:    return String(localized: "Complete 2 levels without hints")
        }
    }

    var type: QuestType {
        switch self {
        case .levelUp, .bingeSolver:        return .completeLevels
        case .starHunter, .perfectionist:   return .perfectClears
        case .pureFocus, .zenMaster:        return .hintlessClears
        case .dailyPilgrim:                 return .solveDailyPuzzle
        }
    }

    var target: Int {
        switch self {
        case .levelUp:       return 3
        case .starHunter:    return 2
        case .pureFocus:     return 1
        case .dailyPilgrim:  return 1
        case .bingeSolver:   return 5
        case .perfectionist: return 3
        case .zenMaster:     return 2
        }
    }

    var reward: Int {
        switch self {
        case .levelUp:       return 30
        case .starHunter:    return 50
        case .pureFocus:     return 40
        case .dailyPilgrim:  return 60
        case .bingeSolver:   return 50
        case .perfectionist: return 70
        case .zenMaster:     return 60
        }
    }
}

struct DailyQuest: Identifiable, Codable, Sendable {
    let id: String
    let template: QuestTemplateID?
    let type: QuestType
    let target: Int
    let reward: Int        // coins
    var progress: Int

    /// Builds before the localization pass stored already-resolved strings.
    /// Kept only so quests saved by those builds still render until the UTC
    /// day rolls over and fresh, template-backed quests replace them.
    private let storedTitle: String?
    private let storedDetails: String?

    var title: String { template?.title ?? storedTitle ?? "" }
    var details: String { template?.details ?? storedDetails ?? "" }

    var isComplete: Bool { progress >= target }
    var progressFraction: Double { min(1.0, Double(progress) / Double(max(1, target))) }

    init(id: String, template: QuestTemplateID, progress: Int = 0) {
        self.id = id
        self.template = template
        self.type = template.type
        self.target = template.target
        self.reward = template.reward
        self.progress = progress
        self.storedTitle = nil
        self.storedDetails = nil
    }

    enum CodingKeys: String, CodingKey {
        case id, template, type, target, reward, progress
        case storedTitle = "title"
        case storedDetails = "description"
    }
}

struct DailyQuestState: Codable, Sendable {
    var date: String           // yyyy-MM-dd UTC
    var quests: [DailyQuest]
    var claimedRewards: Set<String>   // quest IDs whose coins have been granted

    static let empty = DailyQuestState(date: "", quests: [], claimedRewards: [])
}
