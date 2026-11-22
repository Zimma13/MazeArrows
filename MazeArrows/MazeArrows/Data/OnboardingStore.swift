//
//  OnboardingStore.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import Observation

enum OnboardingStep: String, Codable, Sendable {
    case tutorialOne
    case tutorialTwo
    case tutorialThree
    case tutorialFour
    case streak
    case pushPrompt
    case themePicker
    case handoff

    var isTutorial: Bool {
        switch self {
        case .tutorialOne, .tutorialTwo, .tutorialThree, .tutorialFour:
            return true
        default:
            return false
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "paywallIntro", "paywallTimeline", "paywallPlans":
            // Earlier versions placed an offer between lessons three and four.
            self = .tutorialFour
        default:
            guard let step = Self(rawValue: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown onboarding step: \(value)"
                )
            }
            self = step
        }
    }
}

enum OnboardingCompletion: String, Codable, Sendable {
    case completed
    case skipped
}

enum OnboardingExitDestination: Sendable {
    case levelFive
    case worldMap
}

private struct OnboardingSnapshot: Codable, Sendable {
    var version: Int
    var step: OnboardingStep
    var completion: OnboardingCompletion?
    // Keep the field expected by older readers of the v1 snapshot.
    var paywallWasShown: Bool
    var starterRewardWasClaimed: Bool

    static let initial = OnboardingSnapshot(
        version: 1,
        step: .tutorialOne,
        completion: nil,
        paywallWasShown: false,
        starterRewardWasClaimed: false
    )
}

@MainActor
@Observable
final class OnboardingStore {
    static let currentVersion = 1

    private let defaults: UserDefaults
    private let defaultsKey = "MazeArrows.Onboarding.v1"

    private var snapshot: OnboardingSnapshot {
        didSet { save() }
    }

    private(set) var exitDestination: OnboardingExitDestination?

    var step: OnboardingStep { snapshot.step }
    var completion: OnboardingCompletion? { snapshot.completion }
    var shouldShow: Bool { snapshot.completion == nil }

    init(
        defaults: UserDefaults = .standard,
        progressStore: ProgressStore = .shared
    ) {
        self.defaults = defaults

        #if DEBUG
        let forceReset = ProcessInfo.processInfo.arguments.contains("-resetOnboarding")
        if forceReset {
            defaults.removeObject(forKey: defaultsKey)
        }
        #else
        let forceReset = false
        #endif

        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(OnboardingSnapshot.self, from: data) {
            var recovered = decoded

            // The streak reward is one-shot. On relaunch, continue after its
            // presentation instead of showing the celebration twice.
            if recovered.completion == nil,
               recovered.starterRewardWasClaimed,
               recovered.step == .streak {
                recovered.step = .pushPrompt
            }

            self.snapshot = recovered
        } else if !forceReset, Self.hasExistingProgress(progressStore.progress) {
            // Existing installations must not suddenly receive first-launch
            // onboarding after an app update.
            self.snapshot = OnboardingSnapshot(
                version: Self.currentVersion,
                step: .handoff,
                completion: .completed,
                paywallWasShown: false,
                starterRewardWasClaimed: false
            )
        } else {
            self.snapshot = .initial
        }

        save()
    }

    func move(to step: OnboardingStep) {
        guard shouldShow else { return }
        snapshot.step = step
    }

    func claimStarterReward(in progressStore: ProgressStore) {
        guard shouldShow, !snapshot.starterRewardWasClaimed else { return }
        progressStore.grantOnboardingStarterReward()
        var updated = snapshot
        updated.starterRewardWasClaimed = true
        snapshot = updated
    }

    func skip() {
        guard shouldShow else { return }
        var updated = snapshot
        updated.completion = .skipped
        snapshot = updated
    }

    func complete(
        in progressStore: ProgressStore,
        destination: OnboardingExitDestination
    ) {
        guard shouldShow else { return }
        progressStore.applyCompletedOnboardingProgress()
        exitDestination = destination
        var updated = snapshot
        updated.completion = .completed
        snapshot = updated
    }

    #if DEBUG
    func resetForPreview() {
        defaults.removeObject(forKey: defaultsKey)
        snapshot = .initial
    }
    #endif

    private static func hasExistingProgress(_ progress: PlayerProgress) -> Bool {
        progress.unlockedLevelIndex > 1
            || !progress.completedLevels.isEmpty
            || !progress.stars.isEmpty
            || !progress.bestTimes.isEmpty
            || progress.coins > 0
            || progress.dailyStreak > 0
            || !progress.earnedAchievements.isEmpty
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
