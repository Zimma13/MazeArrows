//
//  AnalyticsTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

@MainActor
private final class SpyAnalyticsClient: AnalyticsClient {
    private(set) var events: [AnalyticsEvent] = []
    func log(_ event: AnalyticsEvent) { events.append(event) }
}

/// Installs a spy for the duration of one synchronous test body.
/// Tests are MainActor-isolated and fully synchronous, so no interleaving.
@MainActor
private func withSpy(_ body: (SpyAnalyticsClient) -> Void) {
    let spy = SpyAnalyticsClient()
    let previous = Analytics.client
    Analytics.client = spy
    defer { Analytics.client = previous }
    body(spy)
}

@MainActor
struct AnalyticsWiringTests {

    @Test func startupAndLevelEventsExposeStableNamesAndParameters() {
        let ready = AnalyticsEvent.levelReady(
            contentID: "story:5",
            mode: "story",
            durationMilliseconds: 184
        )
        #expect(ready.name == "level_ready")
        #expect(ready.parameters == [
            "content_id": "story:5",
            "mode": "story",
            "duration_ms": "184"
        ])

        let completed = AnalyticsEvent.levelCompleted(
            contentID: "daily:2026-08-12",
            mode: "daily",
            durationSeconds: 43,
            mistakes: 1,
            hintsUsed: 0,
            maxCombo: 6
        )
        #expect(completed.name == "level_completed")
        #expect(completed.parameters["duration_seconds"] == "43")
        #expect(completed.parameters["mistakes"] == "1")
        #expect(completed.parameters["hints_used"] == "0")
        #expect(completed.parameters["max_combo"] == "6")

        let gameCenter = AnalyticsEvent.gameCenterAuthenticated(
            isUnderage: false,
            isMultiplayerRestricted: true,
            isCommunicationRestricted: true
        )
        #expect(gameCenter.name == "game_center_authenticated")
        #expect(gameCenter.parameters == [
            "underage": "false",
            "multiplayer_restricted": "true",
            "communication_restricted": "true"
        ])

        let review = AnalyticsEvent.reviewRequestAttempted(trigger: "story_clear")
        #expect(review.name == "review_request_attempted")
        #expect(review.parameters == ["trigger": "story_clear"])
    }

    private func makeStore(coins: Int = 0) -> ProgressStore {
        let name = "MazeArrowsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let store = ProgressStore(defaults: defaults)
        store.progress.coins = coins
        return store
    }

    private func makeLevel() -> Level {
        Level(
            id: "analytics-test",
            index: 1,
            difficulty: .easy,
            width: 4,
            height: 4,
            lives: 3,
            pieces: [
                ArrowPiece(id: "a", cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)], direction: .left)
            ]
        )
    }

    @Test func purchasesLogCoinsSpentWithBalance() {
        withSpy { spy in
            var config = EconomyConfig.default
            config.hintCost = 40
            let store = makeStore(coins: 100)

            store.purchaseHint(config: config)

            #expect(spy.events == [.coinsSpent(sink: "hint", amount: 40, balance: 60)])
        }
    }

    @Test func failedPurchaseLogsNothing() {
        withSpy { spy in
            let store = makeStore(coins: 0)
            store.purchaseHint(config: .default)
            store.purchaseRevive(config: .default)
            #expect(spy.events.isEmpty)
        }
    }

    @Test func hintOfferFlowLogsShownAndConverted() {
        withSpy { spy in
            var config = EconomyConfig.default
            config.hintCost = 40
            let store = makeStore(coins: 100)
            store.progress.hintsCount = 0
            let model = GameViewModel(
                level: makeLevel(),
                mode: .story(index: 1),
                gameMode: .classic,
                progressStore: store,
                economyConfig: config
            )
            let scene = GameScene(level: makeLevel(), theme: .aurora, size: CGSize(width: 300, height: 300))
            model.scene = scene
            model.beginSession()

            model.consumeHint()
            #expect(spy.events == [
                .offerShown(
                    context: "hint",
                    slots: ["rewarded", "coins", "premium"]
                )
            ])

            model.purchaseOfferedResource()
            #expect(spy.events == [
                .offerShown(
                    context: "hint",
                    slots: ["rewarded", "coins", "premium"]
                ),
                .coinsSpent(sink: "hint", amount: 40, balance: 60),
                .offerConverted(context: "hint", slot: "coins")
            ])
        }
    }

    @Test func reviveFlowLogsOfferedAndUsed() {
        withSpy { spy in
            var config = EconomyConfig.default
            config.reviveCost = 150
            let store = makeStore(coins: 200)
            let model = GameViewModel(
                level: makeLevel(),
                mode: .story(index: 1),
                gameMode: .classic,
                progressStore: store,
                economyConfig: config
            )
            model.beginSession()

            model.debugDeclareFailure(reason: .outOfLives)
            #expect(spy.events == [.reviveOffered])

            model.requestRevive()
            #expect(spy.events == [
                .reviveOffered,
                .coinsSpent(sink: "revive", amount: 150, balance: 50),
                .reviveUsed
            ])
        }
    }

    @Test func goalFailureDoesNotLogReviveOffer() {
        withSpy { spy in
            let model = GameViewModel(
                level: makeLevel(),
                mode: .story(index: 1),
                gameMode: .classic,
                progressStore: makeStore(),
                economyConfig: .default
            )
            model.beginSession()
            model.debugDeclareFailure(reason: .goalFailed)
            #expect(spy.events.isEmpty)
        }
    }

    @Test func streakFreezeUseAndChestClaimAreLogged() {
        withSpy { spy in
            var config = EconomyConfig.default
            config.streakChests = [3: 100]
            let store = makeStore()
            store.progress.streakFreezes = 1

            store.recordDailyCompletion(date: "2026-08-01", mistakesCount: 0, level: makeLevel(), config: config)
            store.recordDailyCompletion(date: "2026-08-02", mistakesCount: 0, level: makeLevel(), config: config)
            // Missed day covered by the freeze; streak hits 3 → chest.
            store.recordDailyCompletion(date: "2026-08-04", mistakesCount: 0, level: makeLevel(), config: config)

            #expect(spy.events.contains(.streakFreezeUsed))
            #expect(spy.events.contains(.streakChestClaimed(day: 3, coins: 100)))
        }
    }

    @Test func masterClearIsLoggedOnceWithModifier() {
        withSpy { spy in
            let store = makeStore()

            store.recordMasterCompletion(levelIndex: 7, modifier: .hard, config: .default)
            store.recordMasterCompletion(levelIndex: 7, modifier: .hard, config: .default)

            let masterEvents = spy.events.filter {
                if case .masterClear = $0 { return true }
                return false
            }
            #expect(masterEvents == [.masterClear(levelIndex: 7, modifier: "hard")])
        }
    }

    @Test func zenSessionLogsLevelStart() {
        withSpy { spy in
            let model = GameViewModel(
                level: makeLevel(),
                mode: .zen(date: "2026-08-05", index: 2),
                gameMode: .relax,
                progressStore: makeStore(),
                economyConfig: .default
            )
            model.beginSession()
            #expect(spy.events == [.zenLevelStart(index: 2)])
        }
    }
}
