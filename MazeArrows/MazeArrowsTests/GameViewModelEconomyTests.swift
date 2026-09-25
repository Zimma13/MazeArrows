//
//  GameViewModelEconomyTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

@MainActor
struct GameViewModelEconomyTests {

    private static let config: EconomyConfig = {
        var config = EconomyConfig.default
        config.hintCost = 40
        config.undoCost = 20
        config.reviveCost = 150
        config.reviveLives = 2
        return config
    }()

    /// One free arrow at the top-left pointing left — always solvable.
    private func makeLevel(lives: Int = 3) -> Level {
        Level(
            id: "test-level",
            index: 1,
            difficulty: .easy,
            width: 4,
            height: 4,
            lives: lives,
            pieces: [
                ArrowPiece(id: "a", cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)], direction: .left)
            ]
        )
    }

    private func makeModel(
        coins: Int,
        hints: Int = 3,
        undos: Int = 5,
        gameMode: GameMode = .classic,
        premiumAccess: PremiumAccessPolicy = .free
    ) -> (GameViewModel, ProgressStore) {
        let suiteName = "MazeArrowsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = ProgressStore(defaults: defaults)
        store.progress.coins = coins
        store.progress.hintsCount = hints
        store.progress.undosCount = undos
        let model = GameViewModel(
            level: makeLevel(),
            mode: .story(index: 1),
            gameMode: gameMode,
            progressStore: store,
            economyConfig: Self.config,
            premiumAccess: premiumAccess
        )
        return (model, store)
    }

    // MARK: - revive

    @Test func reviveRestoresLivesAndClearsFailure() {
        let (model, store) = makeModel(coins: 200)
        model.beginSession()
        model.debugDeclareFailure(reason: .outOfLives)
        #expect(model.isFailed)
        #expect(model.canRevive)

        model.requestRevive()

        #expect(!model.isFailed)
        #expect(model.failReason == nil)
        #expect(model.lives == Self.config.reviveLives)
        #expect(store.progress.coins == 50)
    }

    @Test func reviveWithoutFundsOpensOfferAndKeepsFailure() {
        let (model, store) = makeModel(coins: 100)
        model.beginSession()
        model.debugDeclareFailure(reason: .outOfLives)

        model.requestRevive()

        #expect(model.isFailed)
        #expect(model.resourceOffer == .revive)
        #expect(store.progress.coins == 100)
    }

    @Test func reviveUnavailableForTimeUpAndGoalFails() {
        for reason: GameViewModel.FailReason in [.timeUp, .goalFailed] {
            let (model, store) = makeModel(coins: 500)
            model.beginSession()
            model.debugDeclareFailure(reason: reason)

            #expect(!model.canRevive)
            model.requestRevive()

            #expect(model.isFailed)
            #expect(model.resourceOffer == nil)
            #expect(store.progress.coins == 500)
        }
    }

    @Test func purchaseOfferedReviveAppliesAfterTopUp() {
        let (model, store) = makeModel(coins: 100)
        model.beginSession()
        model.debugDeclareFailure(reason: .outOfLives)
        model.requestRevive()
        #expect(model.resourceOffer == .revive)

        // Balance changed while the sheet was open (e.g. future rewarded slot).
        store.progress.coins = 150
        model.purchaseOfferedResource()

        #expect(!model.isFailed)
        #expect(model.resourceOffer == nil)
        #expect(store.progress.coins == 0)
        #expect(model.lives == Self.config.reviveLives)
    }

    // MARK: - hint / undo offers

    @Test func consumeHintWithEmptyBalanceOpensOffer() {
        let (model, _) = makeModel(coins: 0, hints: 0)
        let scene = GameScene(level: makeLevel(), theme: .aurora, size: CGSize(width: 300, height: 300))
        model.scene = scene
        model.beginSession()

        model.consumeHint()

        #expect(model.resourceOffer == .hint)
        #expect(model.hintsUsed == 0)
    }

    @Test func purchasingOfferedHintAppliesItImmediately() {
        let (model, store) = makeModel(coins: 100, hints: 0)
        let scene = GameScene(level: makeLevel(), theme: .aurora, size: CGSize(width: 300, height: 300))
        model.scene = scene
        model.beginSession()

        model.consumeHint()
        #expect(model.resourceOffer == .hint)

        model.purchaseOfferedResource()

        #expect(model.resourceOffer == nil)
        #expect(model.hintsUsed == 1)
        #expect(store.progress.coins == 60)
        #expect(store.progress.hintsCount == 0)   // granted, then consumed by the retry
    }

    @Test func premiumHintIsUnlimitedButStillCountsAsUsed() {
        let (model, store) = makeModel(
            coins: 0,
            hints: 0,
            premiumAccess: .premium
        )
        let scene = GameScene(
            level: makeLevel(),
            theme: .aurora,
            size: CGSize(width: 300, height: 300)
        )
        model.scene = scene
        model.beginSession()

        model.consumeHint()

        #expect(model.resourceOffer == nil)
        #expect(model.hasUnlimitedHints)
        #expect(model.hintsUsed == 1)
        #expect(store.progress.hintsCount == 0)
    }

    @Test func premiumUnlockFromHintOfferContinuesInterruptedHint() {
        let (model, store) = makeModel(coins: 0, hints: 0)
        let scene = GameScene(
            level: makeLevel(),
            theme: .aurora,
            size: CGSize(width: 300, height: 300)
        )
        model.scene = scene
        model.beginSession()

        model.consumeHint()
        #expect(model.resourceOffer == .hint)

        model.continueHintAfterPremiumUnlock()

        #expect(model.resourceOffer == nil)
        #expect(model.hasUnlimitedHints)
        #expect(model.hintsUsed == 1)
        #expect(store.progress.hintsCount == 0)
        #expect(store.progress.coins == 0)
    }

    @Test func premiumDoesNotOverrideModesThatDisableHints() {
        let (model, _) = makeModel(
            coins: 0,
            hints: 0,
            gameMode: .hard,
            premiumAccess: .premium
        )
        let scene = GameScene(
            level: makeLevel(),
            theme: .aurora,
            size: CGSize(width: 300, height: 300)
        )
        model.scene = scene
        model.beginSession()

        model.consumeHint()

        #expect(!model.hasUnlimitedHints)
        #expect(model.resourceOffer == nil)
        #expect(model.hintsUsed == 0)
    }

    @Test func purchaseOfferedHintWithoutFundsChangesNothing() {
        let (model, store) = makeModel(coins: 10, hints: 0)
        let scene = GameScene(level: makeLevel(), theme: .aurora, size: CGSize(width: 300, height: 300))
        model.scene = scene
        model.beginSession()

        model.consumeHint()
        model.purchaseOfferedResource()

        #expect(model.resourceOffer == .hint)     // sheet stays open
        #expect(model.hintsUsed == 0)
        #expect(store.progress.coins == 10)
    }

    @Test func rewardedHintAppliesImmediatelyWithoutCoins() {
        let (model, store) = makeModel(coins: 0, hints: 0)
        let scene = GameScene(
            level: makeLevel(),
            theme: .aurora,
            size: CGSize(width: 300, height: 300)
        )
        model.scene = scene
        model.beginSession()
        model.consumeHint()

        #expect(model.applyRewardedOffer(.hint))
        #expect(model.resourceOffer == nil)
        #expect(model.hintsUsed == 1)
        #expect(store.progress.hintsCount == 0)
        #expect(store.progress.coins == 0)
    }

    @Test func rewardedUndoIsKeptWhenInterruptedActionIsNoLongerAvailable() {
        let (model, store) = makeModel(coins: 0, undos: 0)
        model.beginSession()
        model.resourceOffer = .undo

        #expect(model.applyRewardedOffer(.undo))
        #expect(model.resourceOffer == nil)
        #expect(store.progress.undosCount == 1)
        #expect(store.progress.coins == 0)
    }

    @Test func rewardedReviveRestoresLivesWithoutChargingCoins() {
        let (model, store) = makeModel(coins: 0)
        model.beginSession()
        model.debugDeclareFailure(reason: .outOfLives)
        model.requestRevive()

        #expect(model.resourceOffer == .revive)
        #expect(model.applyRewardedOffer(.revive))
        #expect(!model.isFailed)
        #expect(model.lives == Self.config.reviveLives)
        #expect(store.progress.coins == 0)
    }

    @Test func rewardedCallbackCannotApplyAStaleOrDifferentOffer() {
        let (model, store) = makeModel(coins: 0, hints: 0, undos: 0)
        model.beginSession()
        model.resourceOffer = .hint

        #expect(!model.applyRewardedOffer(.undo))
        #expect(model.resourceOffer == .hint)
        #expect(store.progress.hintsCount == 0)
        #expect(store.progress.undosCount == 0)
    }

    @Test func hardModeNeverOffersHints() {
        let (model, _) = makeModel(coins: 500, hints: 0, gameMode: .hard)
        let scene = GameScene(level: makeLevel(), theme: .aurora, size: CGSize(width: 300, height: 300))
        model.scene = scene
        model.beginSession()

        model.consumeHint()

        #expect(model.resourceOffer == nil)
    }

    @Test func restartClearsFailReasonAndOffer() {
        let (model, _) = makeModel(coins: 0, hints: 0)
        let scene = GameScene(level: makeLevel(), theme: .aurora, size: CGSize(width: 300, height: 300))
        model.scene = scene
        model.beginSession()
        model.debugDeclareFailure(reason: .outOfLives)
        model.requestRevive()
        #expect(model.resourceOffer == .revive)

        model.restart()

        #expect(!model.isFailed)
        #expect(model.failReason == nil)
        #expect(model.resourceOffer == nil)
    }

    @Test func pricesComeFromInjectedConfig() {
        let (model, _) = makeModel(coins: 0)
        #expect(model.price(for: .hint) == 40)
        #expect(model.price(for: .undo) == 20)
        #expect(model.price(for: .revive) == 150)
        #expect(!model.canAfford(.hint))
    }
}
