//
//  DailyQuestProvider.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

@MainActor
final class DailyQuestProvider {
    static let shared = DailyQuestProvider()
    private init() {}

    func todayDateString(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: now)
    }

    func questsForToday() -> [DailyQuest] {
        let today = todayDateString()
        return quests(for: today)
    }

    func quests(for dateString: String) -> [DailyQuest] {
        var rng = SeededRandomNumberGenerator(seed: seed(for: dateString))

        // Pool order is part of the daily seed contract — keep it stable.
        var pool = QuestTemplateID.allCases
        var picked: [QuestTemplateID] = []
        while picked.count < 3 && !pool.isEmpty {
            let idx = Int(rng.next() % UInt64(pool.count))
            picked.append(pool.remove(at: idx))
        }

        return picked.enumerated().map { i, template in
            DailyQuest(id: "quest_\(dateString)_\(i)", template: template)
        }
    }

    private func seed(for dateString: String) -> UInt64 {
        stableHash64("quests_v1_" + dateString)
    }
}
