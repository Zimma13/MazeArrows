//
//  InterstitialAdFrequencyPolicyTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

@MainActor
struct InterstitialAdFrequencyPolicyTests {
    @Test func firstInterstitialWaitsForFiveEligibleCompletions() {
        let policy = InterstitialAdFrequencyPolicy.standard
        var state = InterstitialAdFrequencyPolicy.State()
        let now = Date(timeIntervalSince1970: 1_000)

        for _ in 0..<4 {
            #expect(!policy.recordEligibleCompletion(in: &state, now: now))
        }
        #expect(policy.recordEligibleCompletion(in: &state, now: now))
        #expect(state.eligibleCompletionsSinceLastPresentation == 5)
        #expect(state.presentationCount == 0)
    }

    @Test func recurringInterstitialNeedsFourMoreCompletionsAndCooldown() {
        let policy = InterstitialAdFrequencyPolicy.standard
        let firstPresentation = Date(timeIntervalSince1970: 1_000)
        var state = InterstitialAdFrequencyPolicy.State(
            eligibleCompletionsSinceLastPresentation: 5
        )
        policy.recordPresentation(in: &state, now: firstPresentation)

        for offset in 1...4 {
            let now = firstPresentation.addingTimeInterval(Double(offset * 10))
            #expect(!policy.recordEligibleCompletion(in: &state, now: now))
        }

        let afterCooldown = firstPresentation.addingTimeInterval(181)
        #expect(policy.recordEligibleCompletion(in: &state, now: afterCooldown))
        policy.recordPresentation(in: &state, now: afterCooldown)
        #expect(state.eligibleCompletionsSinceLastPresentation == 0)
        #expect(state.presentationCount == 2)
    }

    @Test func onlyFirstCampaignClearIsMarkedEligible() {
        let store = makeProgressStore()
        let level = makeLevel(index: 1)

        let first = GameViewModel(
            level: level,
            mode: .story(index: 1),
            progressStore: store
        )
        first.beginSession()
        first.debugDeclareVictory()
        #expect(first.isFirstStoryCompletion)

        let replay = GameViewModel(
            level: level,
            mode: .story(index: 1),
            progressStore: store
        )
        replay.beginSession()
        replay.debugDeclareVictory()
        #expect(!replay.isFirstStoryCompletion)

        let daily = GameViewModel(
            level: makeLevel(index: 2),
            mode: .daily(date: "2026-08-13"),
            progressStore: store
        )
        daily.beginSession()
        daily.debugDeclareVictory()
        #expect(!daily.isFirstStoryCompletion)
    }

    private func makeProgressStore() -> ProgressStore {
        let suiteName = "InterstitialAdFrequencyPolicyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated defaults for interstitial policy tests.")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return ProgressStore(defaults: defaults)
    }

    private func makeLevel(index: Int) -> Level {
        Level(
            id: "interstitial-policy-\(index)",
            index: index,
            difficulty: .easy,
            width: 3,
            height: 3,
            lives: 3,
            pieces: [
                ArrowPiece(
                    id: "piece-\(index)",
                    cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)],
                    direction: .left
                )
            ]
        )
    }
}
