//
//  InterstitialAdFrequencyPolicy.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

/// A conservative, persistent schedule for non-rewarded full-screen ads.
/// Only first-time campaign clears are recorded by the caller.
struct InterstitialAdFrequencyPolicy: Equatable, Sendable {
    struct State: Equatable, Sendable {
        var eligibleCompletionsSinceLastPresentation = 0
        var presentationCount = 0
        var lastPresentedAt: Date?
    }

    static let standard = InterstitialAdFrequencyPolicy(
        firstPresentationAfterCompletions: 5,
        recurringPresentationInterval: 4,
        minimumTimeBetweenPresentations: 180
    )

    let firstPresentationAfterCompletions: Int
    let recurringPresentationInterval: Int
    let minimumTimeBetweenPresentations: TimeInterval

    init(
        firstPresentationAfterCompletions: Int,
        recurringPresentationInterval: Int,
        minimumTimeBetweenPresentations: TimeInterval
    ) {
        self.firstPresentationAfterCompletions = max(1, firstPresentationAfterCompletions)
        self.recurringPresentationInterval = max(1, recurringPresentationInterval)
        self.minimumTimeBetweenPresentations = max(0, minimumTimeBetweenPresentations)
    }

    /// Records one first-time campaign clear and reports whether an ad break is due.
    func recordEligibleCompletion(in state: inout State, now: Date) -> Bool {
        state.eligibleCompletionsSinceLastPresentation += 1

        let requiredCompletions = state.presentationCount == 0
            ? firstPresentationAfterCompletions
            : recurringPresentationInterval
        guard state.eligibleCompletionsSinceLastPresentation >= requiredCompletions else {
            return false
        }

        guard let lastPresentedAt = state.lastPresentedAt else { return true }
        return now.timeIntervalSince(lastPresentedAt) >= minimumTimeBetweenPresentations
    }

    /// Commits only a presentation confirmed by the SDK delegate.
    func recordPresentation(in state: inout State, now: Date) {
        state.eligibleCompletionsSinceLastPresentation = 0
        state.presentationCount += 1
        state.lastPresentedAt = now
    }
}
