//
//  ZenAndMasterTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

private func makeIsolatedStore() -> ProgressStore {
    let name = "MazeArrowsTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return ProgressStore(defaults: defaults)
}

@MainActor
struct ZenLimitTests {

    private var config: EconomyConfig {
        var config = EconomyConfig.default
        config.zenFreeLevelsPerDay = 3
        return config
    }

    @Test func remainingCountsDownWithinDay() {
        let store = makeIsolatedStore()
        #expect(store.zenRemainingToday(date: "2026-08-05", config: config) == 3)

        store.recordZenCompletion(date: "2026-08-05")
        store.recordZenCompletion(date: "2026-08-05")
        #expect(store.zenRemainingToday(date: "2026-08-05", config: config) == 1)

        store.recordZenCompletion(date: "2026-08-05")
        #expect(store.zenRemainingToday(date: "2026-08-05", config: config) == 0)
    }

    @Test func limitResetsOnNewDay() {
        let store = makeIsolatedStore()
        for _ in 0..<3 { store.recordZenCompletion(date: "2026-08-05") }
        #expect(store.zenRemainingToday(date: "2026-08-05", config: config) == 0)

        #expect(store.zenRemainingToday(date: "2026-08-06", config: config) == 3)
        store.recordZenCompletion(date: "2026-08-06")
        #expect(store.progress.zenPlayedCount == 1)
        #expect(store.progress.zenPlayedDate == "2026-08-06")
    }

    @Test func zenCompletionGrantsNothing() {
        let store = makeIsolatedStore()
        let before = store.progress

        store.recordZenCompletion(date: "2026-08-05")

        #expect(store.progress.coins == before.coins)
        #expect(store.progress.completedLevels == before.completedLevels)
        #expect(store.progress.stars == before.stars)
        #expect(store.progress.dailyQuestState.quests.map(\.progress)
            == before.dailyQuestState.quests.map(\.progress))
    }
}

struct ZenProviderTests {

    @Test func difficultyRampsGently() {
        #expect(ZenProvider.difficulty(forIndex: 0) == .easy)
        #expect(ZenProvider.difficulty(forIndex: 1) == .medium)
        #expect(ZenProvider.difficulty(forIndex: 2) == .medium)
        #expect(ZenProvider.difficulty(forIndex: 3) == .hard)
        #expect(ZenProvider.difficulty(forIndex: 42) == .hard)
    }

    @Test func sameDayAndIndexIsDeterministic() async throws {
        let a = try await ZenProvider.shared.level(date: "2026-08-05", index: 0)
        let b = try await ZenProvider.shared.level(date: "2026-08-05", index: 0)
        #expect(a.id == b.id)
        #expect(a.pieces == b.pieces)
        #expect(!a.pieces.isEmpty)
    }

    @Test func differentIndexGivesDifferentLevel() async throws {
        let a = try await ZenProvider.shared.level(date: "2026-08-05", index: 0)
        let b = try await ZenProvider.shared.level(date: "2026-08-05", index: 1)
        #expect(a.id != b.id)
    }
}

@MainActor
struct MasterLayerTests {

    private var config: EconomyConfig {
        var config = EconomyConfig.default
        config.masterClearReward = 25
        return config
    }

    @Test func rewardIsOneTimePerModifier() {
        let store = makeIsolatedStore()

        #expect(store.recordMasterCompletion(levelIndex: 7, modifier: .challenge, config: config) == 25)
        #expect(store.progress.coins == 25)
        #expect(store.masterClears(levelIndex: 7) == [.challenge])

        // Same pair again — nothing.
        #expect(store.recordMasterCompletion(levelIndex: 7, modifier: .challenge, config: config) == 0)
        #expect(store.progress.coins == 25)

        // A different modifier on the same level earns a new crown.
        #expect(store.recordMasterCompletion(levelIndex: 7, modifier: .hard, config: config) == 25)
        #expect(store.progress.coins == 50)
        #expect(store.masterClears(levelIndex: 7) == [.challenge, .hard])
    }

    @Test func onlyMasterModifiersCount() {
        let store = makeIsolatedStore()
        for modifier: GameMode in [.classic, .relax, .zenDaily] {
            #expect(store.recordMasterCompletion(levelIndex: 3, modifier: modifier, config: config) == 0)
        }
        #expect(store.progress.coins == 0)
        #expect(store.masterClears(levelIndex: 3).isEmpty)
    }

    @Test func masterDoesNotTouchCampaignProgress() {
        let store = makeIsolatedStore()
        store.progress.completedLevels = [1, 2]
        store.progress.stars = [1: 2, 2: 3]
        store.progress.unlockedLevelIndex = 3
        let questsBefore = store.progress.dailyQuestState.quests.map(\.progress)

        store.recordMasterCompletion(levelIndex: 2, modifier: .timed, config: config)

        #expect(store.progress.completedLevels == [1, 2])
        #expect(store.progress.stars == [1: 2, 2: 3])
        #expect(store.progress.unlockedLevelIndex == 3)
        #expect(store.progress.bestTimes.isEmpty)
        #expect(store.progress.dailyQuestState.quests.map(\.progress) == questsBefore)
    }
}

@MainActor
struct ZenMasterViewModelTests {

    private func makeLevel() -> Level {
        Level(
            id: "vm-test-level",
            index: 9,
            difficulty: .easy,
            width: 4,
            height: 4,
            lives: 3,
            pieces: [
                ArrowPiece(id: "a", cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)], direction: .left)
            ]
        )
    }

    @Test func zenVictoryCountsPlayButPaysNothing() {
        let store = makeIsolatedStore()
        store.progress.coins = 10
        let model = GameViewModel(
            level: makeLevel(),
            mode: .zen(date: "2026-08-05", index: 0),
            gameMode: .relax,
            progressStore: store,
            economyConfig: .default
        )
        model.beginSession()

        model.debugDeclareVictory()

        #expect(store.progress.zenPlayedCount == 1)
        #expect(store.progress.coins == 10)
        #expect(model.completionCoinReward == 0)
        #expect(store.progress.completedLevels.isEmpty)
    }

    @Test func masterVictoryPaysOnceThroughViewModel() {
        let store = makeIsolatedStore()
        var config = EconomyConfig.default
        config.masterClearReward = 25

        let first = GameViewModel(
            level: makeLevel(),
            mode: .master(index: 9),
            gameMode: .challenge,
            progressStore: store,
            economyConfig: config
        )
        first.beginSession()
        first.debugDeclareVictory()

        #expect(store.progress.coins == 25)
        #expect(first.completionCoinReward == 25)
        #expect(store.masterClears(levelIndex: 9) == [.challenge])

        let second = GameViewModel(
            level: makeLevel(),
            mode: .master(index: 9),
            gameMode: .challenge,
            progressStore: store,
            economyConfig: config
        )
        second.beginSession()
        second.debugDeclareVictory()

        #expect(store.progress.coins == 25)
        #expect(second.completionCoinReward == 0)
    }
}
