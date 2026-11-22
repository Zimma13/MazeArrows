//
//  EconomyTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

private func makeIsolatedDefaults() -> UserDefaults {
    let name = "MazeArrowsTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@MainActor
struct ProgressStoreEconomyTests {

    private func makeStore(coins: Int = 0) -> ProgressStore {
        let store = ProgressStore(defaults: makeIsolatedDefaults())
        store.progress.coins = coins
        return store
    }

    // MARK: spendCoins

    @Test func spendWithinBalanceSucceeds() {
        let store = makeStore(coins: 100)
        #expect(store.spendCoins(60))
        #expect(store.progress.coins == 40)
    }

    @Test func spendBeyondBalanceFailsAndKeepsBalance() {
        let store = makeStore(coins: 50)
        #expect(!store.spendCoins(100))
        #expect(store.progress.coins == 50)
    }

    @Test func spendZeroOrNegativeFails() {
        let store = makeStore(coins: 50)
        #expect(!store.spendCoins(0))
        #expect(!store.spendCoins(-10))
        #expect(store.progress.coins == 50)
    }

    @Test func spendExactBalanceSucceeds() {
        let store = makeStore(coins: 100)
        #expect(store.spendCoins(100))
        #expect(store.progress.coins == 0)
    }

    // MARK: purchases

    @Test func purchaseUndoDeductsCostAndGrantsUndo() {
        var config = EconomyConfig.default
        config.undoCost = 25
        let store = makeStore(coins: 30)
        let undosBefore = store.progress.undosCount

        #expect(store.purchaseUndo(config: config))
        #expect(store.progress.coins == 5)
        #expect(store.progress.undosCount == undosBefore + 1)
    }

    @Test func purchaseReviveOnlySettlesCoins() {
        var config = EconomyConfig.default
        config.reviveCost = 150
        let store = makeStore(coins: 200)

        #expect(store.purchaseRevive(config: config))
        #expect(store.progress.coins == 50)
        #expect(!store.purchaseRevive(config: config))
        #expect(store.progress.coins == 50)
    }

    @Test func purchaseStreakFreezeRespectsCap() {
        var config = EconomyConfig.default
        config.streakFreezeCost = 100
        config.maxStreakFreezes = 2
        let store = makeStore(coins: 1000)

        #expect(store.purchaseStreakFreeze(config: config))
        #expect(store.purchaseStreakFreeze(config: config))
        #expect(store.progress.streakFreezes == 2)

        // At the cap: rejected without touching the balance.
        let coinsBefore = store.progress.coins
        #expect(!store.purchaseStreakFreeze(config: config))
        #expect(store.progress.streakFreezes == 2)
        #expect(store.progress.coins == coinsBefore)
    }

    @Test func purchaseStreakFreezeWithoutFundsFails() {
        var config = EconomyConfig.default
        config.streakFreezeCost = 100
        let store = makeStore(coins: 99)

        #expect(!store.purchaseStreakFreeze(config: config))
        #expect(store.progress.streakFreezes == 0)
        #expect(store.progress.coins == 99)
    }

    // MARK: persistence

    @Test func economyFieldsSurviveStoreReload() {
        let defaults = makeIsolatedDefaults()
        let store = ProgressStore(defaults: defaults)
        store.progress.coins = 500
        var config = EconomyConfig.default
        config.streakFreezeCost = 100
        #expect(store.purchaseStreakFreeze(config: config))

        let reloaded = ProgressStore(defaults: defaults)
        #expect(reloaded.progress.coins == 400)
        #expect(reloaded.progress.streakFreezes == 1)
    }
}

@MainActor
struct EconomyConfigStoreTests {

    @Test func defaultsMatchProposal() {
        let config = EconomyConfig.default
        #expect(config.undoCost == 30)
        #expect(config.reviveCost == 150)
        #expect(config.reviveLives == 2)
        #expect(config.streakFreezeCost == 250)
        #expect(config.maxStreakFreezes == 2)
        #expect(config.masterClearReward == 25)
        #expect(config.streakChests == [3: 50, 7: 100, 14: 200, 30: 400])
    }

    #if DEBUG
    @Test func debugOverrideAppliesOnlyToProvidedKeys() {
        let defaults = makeIsolatedDefaults()
        defaults.set(55, forKey: "economy.undoCost")

        let store = EconomyConfigStore(base: .default, defaults: defaults)
        #expect(store.config.undoCost == 55)
        #expect(store.config.reviveCost == EconomyConfig.default.reviveCost)
    }

    @Test func debugOverrideIgnoresNonPositiveValues() {
        let defaults = makeIsolatedDefaults()
        defaults.set(0, forKey: "economy.undoCost")

        let store = EconomyConfigStore(base: .default, defaults: defaults)
        #expect(store.config.undoCost == EconomyConfig.default.undoCost)
    }
    #endif
}
