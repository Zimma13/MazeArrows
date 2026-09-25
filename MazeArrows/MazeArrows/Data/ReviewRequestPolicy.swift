//
//  ReviewRequestPolicy.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

enum ReviewRequestTrigger: String, Codable, Equatable, Sendable {
    case storyClear = "story_clear"
    case chapterCompleted = "chapter_completed"
    case photoMazeCompleted = "photo_maze_completed"
    case threeDayStreak = "three_day_streak"
}

struct ReviewRequestOpportunity: Equatable, Sendable {
    let trigger: ReviewRequestTrigger
    let completedStoryLevelsAfterOnboarding: Int
    let onboardingCompleted: Bool
    let isFirstCompletion: Bool
    let stars: Int
    let hasUsedRevive: Bool
    let hadCommercialInterruption: Bool
    let streakDays: Int
}

struct ReviewRequestPolicy: Sendable {
    struct State: Codable, Equatable, Sendable {
        var activeDays: Set<Date> = []
        var attemptDates: [Date] = []
        var attemptedVersions: Set<String> = []
        var hasAttemptedAfterPhotoMaze = false
        var hasAttemptedAfterThreeDayStreak = false
    }

    let minimumActiveDays: Int
    let minimumStoryCompletions: Int
    let minimumDaysBetweenAttempts: Int
    let rollingWindowDays: Int
    let maximumAttemptsInRollingWindow: Int

    static let standard = ReviewRequestPolicy(
        minimumActiveDays: 3,
        minimumStoryCompletions: 6,
        minimumDaysBetweenAttempts: 120,
        rollingWindowDays: 365,
        maximumAttemptsInRollingWindow: 2
    )

    func recordActiveDay(
        in state: inout State,
        now: Date,
        calendar: Calendar
    ) {
        state.activeDays.insert(calendar.startOfDay(for: now))
        prune(&state, now: now)
    }

    func isEligible(
        for opportunity: ReviewRequestOpportunity,
        state: State,
        now: Date,
        appVersion: String
    ) -> Bool {
        var currentState = state
        prune(&currentState, now: now)

        guard opportunity.onboardingCompleted,
              opportunity.completedStoryLevelsAfterOnboarding >= minimumStoryCompletions,
              currentState.activeDays.count >= minimumActiveDays,
              !opportunity.hasUsedRevive,
              !opportunity.hadCommercialInterruption,
              !currentState.attemptedVersions.contains(appVersion),
              currentState.attemptDates.count < maximumAttemptsInRollingWindow
        else { return false }

        if let lastAttemptDate = currentState.attemptDates.max(),
           now.timeIntervalSince(lastAttemptDate) < days(minimumDaysBetweenAttempts) {
            return false
        }

        switch opportunity.trigger {
        case .storyClear:
            return opportunity.isFirstCompletion && opportunity.stars >= 2
        case .chapterCompleted:
            return opportunity.isFirstCompletion
        case .photoMazeCompleted:
            return !currentState.hasAttemptedAfterPhotoMaze
        case .threeDayStreak:
            return opportunity.streakDays >= 3
                && !currentState.hasAttemptedAfterThreeDayStreak
        }
    }

    func recordAttempt(
        for trigger: ReviewRequestTrigger,
        in state: inout State,
        now: Date,
        appVersion: String
    ) {
        state.attemptDates.append(now)
        state.attemptedVersions.insert(appVersion)

        switch trigger {
        case .photoMazeCompleted:
            state.hasAttemptedAfterPhotoMaze = true
        case .threeDayStreak:
            state.hasAttemptedAfterThreeDayStreak = true
        case .storyClear, .chapterCompleted:
            break
        }

        prune(&state, now: now)
    }

    private func prune(_ state: inout State, now: Date) {
        let cutoff = now.addingTimeInterval(-days(rollingWindowDays))
        state.activeDays = state.activeDays.filter { $0 >= cutoff }
        state.attemptDates = state.attemptDates.filter { $0 >= cutoff && $0 <= now }
    }

    private func days(_ count: Int) -> TimeInterval {
        TimeInterval(count) * 24 * 60 * 60
    }
}
