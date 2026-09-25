//
//  QuestLocalizationTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

@MainActor
struct QuestLocalizationTests {

    @Test func questsPersistTemplateNotResolvedText() throws {
        let quests = DailyQuestProvider.shared.quests(for: "2026-08-05")
        #expect(quests.count == 3)

        let data = try JSONEncoder().encode(quests)
        let json = String(decoding: data, as: UTF8.self)

        // The payload must carry template ids, never localized copy —
        // otherwise a language switch leaves stale text on screen.
        #expect(json.contains("\"template\""))
        for quest in quests {
            #expect(!json.contains(quest.title))
            #expect(!json.contains(quest.details))
        }
    }

    @Test func decodedQuestResolvesTitleFromTemplate() throws {
        let original = DailyQuest(id: "quest_2026-08-05_0", template: .bingeSolver)
        let decoded = try JSONDecoder().decode(
            DailyQuest.self, from: try JSONEncoder().encode(original)
        )

        #expect(decoded.template == .bingeSolver)
        #expect(decoded.title == QuestTemplateID.bingeSolver.title)
        #expect(decoded.details == QuestTemplateID.bingeSolver.details)
        #expect(decoded.type == .completeLevels)
        #expect(decoded.target == 5)
        #expect(decoded.reward == 50)
    }

    /// Quests saved by pre-localization builds have no template id — they must
    /// still render rather than showing blank rows.
    @Test func legacyPayloadFallsBackToStoredText() throws {
        let legacy = """
        {
            "id": "quest_2026-08-01_0",
            "title": "Level Up",
            "description": "Complete 3 story levels",
            "type": "completeLevels",
            "target": 3,
            "reward": 30,
            "progress": 2
        }
        """
        let quest = try JSONDecoder().decode(DailyQuest.self, from: Data(legacy.utf8))

        #expect(quest.template == nil)
        #expect(quest.title == "Level Up")
        #expect(quest.details == "Complete 3 story levels")
        #expect(quest.progress == 2)
        #expect(!quest.isComplete)
    }

    @Test func templateMetadataMatchesQuestFields() {
        for template in QuestTemplateID.allCases {
            let quest = DailyQuest(id: "q", template: template)
            #expect(quest.type == template.type)
            #expect(quest.target == template.target)
            #expect(quest.reward == template.reward)
            #expect(!quest.title.isEmpty)
            #expect(!quest.details.isEmpty)
        }
    }

    @Test func dailyQuestsAreDeterministicPerDate() {
        let a = DailyQuestProvider.shared.quests(for: "2026-08-05").map(\.template)
        let b = DailyQuestProvider.shared.quests(for: "2026-08-05").map(\.template)
        let c = DailyQuestProvider.shared.quests(for: "2026-08-06").map(\.template)

        #expect(a == b)
        #expect(a != c)
        #expect(Set(a).count == 3)   // no duplicate quests in one day
    }
}
