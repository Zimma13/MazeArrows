//
//  GameViewModelEconomyTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//

import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import MazeArrows

@MainActor
struct GameViewModelEconomyTests {

    private static let config: EconomyConfig = {
        var config = EconomyConfig.default
        config.undoCost = 20
        config.reviveCost = 150
        config.reviveLives = 2
        return config
    }()

    private func makeLevel(goal: LevelGoal = .clearAll) -> Level {
        Level(
            id: "test-level",
            index: 1,
            difficulty: .easy,
            width: 4,
            height: 4,
            lives: 3,
            pieces: [
                ArrowPiece(id: "a", cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)], direction: .left),
                ArrowPiece(id: "b", cells: [GridPoint(x: 1, y: 1), GridPoint(x: 0, y: 1)], direction: .left)
            ],
            goal: goal
        )
    }

    private func makeModel(
        coins: Int,
        hints: Int = 3,
        undos: Int = 5,
        gameMode: GameMode = .classic,
        goal: LevelGoal = .clearAll
    ) -> (GameViewModel, ProgressStore) {
        let suiteName = "MazeArrowsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = ProgressStore(defaults: defaults)
        store.progress.coins = coins
        store.progress.hintsCount = hints
        store.progress.undosCount = undos
        let model = GameViewModel(
            level: makeLevel(goal: goal),
            mode: .story(index: 1),
            gameMode: gameMode,
            progressStore: store,
            economyConfig: Self.config
        )
        return (model, store)
    }

    private func startScene(for model: GameViewModel) -> GameScene {
        let scene = GameScene(level: model.level, theme: .aurora, size: CGSize(width: 300, height: 300), reduceMotion: true)
        scene.didChangeSize(.zero)
        model.scene = scene
        model.beginSession()
        return scene
    }

    private func clear(_ pieceID: String, in scene: GameScene, model: GameViewModel) throws {
        let node = try #require(scene.childNode(withName: "//" + pieceID) as? ArrowPieceNode)
        model.sceneDidTapPiece(pieceID)
        node.interruptActions(completingPendingOperations: true)
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

        // The sheet must use the current balance when confirming the action.
        store.progress.coins = 150
        model.purchaseOfferedResource()

        #expect(!model.isFailed)
        #expect(model.resourceOffer == nil)
        #expect(store.progress.coins == 0)
        #expect(model.lives == Self.config.reviveLives)
    }

    // MARK: - hints and undos

    @Test(arguments: [0, 7])
    func hintsIgnoreLegacyBalanceAndStillCountForTheNoHintsGoal(legacyHints: Int) throws {
        let (model, store) = makeModel(coins: 7, hints: legacyHints, goal: .noHints)
        let scene = startScene(for: model)
        for _ in 0..<12 {
            model.consumeHint()
        }
        #expect(model.hintsUsed == 12)
        #expect(model.resourceOffer == nil)
        #expect(store.progress.coins == 7)
        #expect(store.progress.hintsCount == legacyHints)

        try clear("a", in: scene, model: model)
        try clear("b", in: scene, model: model)
        #expect(model.failReason == .goalFailed)
        #expect(!model.isCompleted)
    }

    @Test func hardModeBlocksHintAndUndoWithAnyBalance() throws {
        let (model, store) = makeModel(coins: 500, hints: 3, undos: 2, gameMode: .hard)
        let scene = startScene(for: model)
        try clear("a", in: scene, model: model)
        model.consumeHint()
        model.consumeUndo()

        #expect(scene.board.pieces.map(\.id) == ["b"])
        #expect(model.hintsUsed == 0)
        #expect(model.resourceOffer == nil)
        #expect(store.progress.hintsCount == 3)
        #expect(store.progress.undosCount == 2)
        #expect(store.progress.coins == 500)
    }

    @Test func savedUndoIsUsedBeforeCoinsAndNextUndoCostsCoins() throws {
        let (model, store) = makeModel(coins: 20, undos: 1)
        let scene = startScene(for: model)
        try clear("a", in: scene, model: model)
        model.consumeUndo()
        #expect(scene.board.pieces.count == 2)
        #expect(store.progress.undosCount == 0)
        #expect(store.progress.coins == 20)
        #expect(model.resourceOffer == nil)

        try clear("a", in: scene, model: model)
        model.consumeUndo()
        #expect(model.resourceOffer == .undo)
        model.purchaseOfferedResource()
        model.purchaseOfferedResource()
        #expect(scene.board.pieces.count == 2)
        #expect(model.resourceOffer == nil)
        #expect(store.progress.undosCount == 0)
        #expect(store.progress.coins == 0)
    }

    @Test func undoWithEmptyBalanceLeavesBoardPlayable() throws {
        let (model, store) = makeModel(coins: 0, undos: 0)
        let scene = startScene(for: model)
        try clear("a", in: scene, model: model)
        model.consumeUndo()
        model.purchaseOfferedResource()
        #expect(model.resourceOffer == .undo)
        #expect(scene.board.pieces.map(\.id) == ["b"])
        #expect(store.progress.coins == 0)

        model.dismissResourceOffer()
        try clear("b", in: scene, model: model)
        #expect(model.isCompleted)
    }

    @Test func restartClearsFailReasonAndOffer() {
        let (model, store) = makeModel(coins: 0, hints: 0)
        let scene = GameScene(level: model.level, theme: .aurora, size: CGSize(width: 300, height: 300))
        model.scene = scene
        model.beginSession()
        model.debugDeclareFailure(reason: .outOfLives)
        model.requestRevive()
        #expect(model.resourceOffer == .revive)

        model.restart()

        #expect(!model.isFailed)
        #expect(model.failReason == nil)
        #expect(model.resourceOffer == nil)
        #expect(store.progress.coins == 0)
        #expect(model.lives == model.totalLives)
    }

    @Test func pricesComeFromInjectedConfig() {
        let (model, _) = makeModel(coins: 0)
        #expect(model.price(for: .undo) == 20)
        #expect(model.price(for: .revive) == 150)
        #expect(!model.canAfford(.undo))
    }
}
