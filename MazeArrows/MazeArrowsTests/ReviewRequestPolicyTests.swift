//
//  ReviewRequestPolicyTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

struct ReviewRequestPolicyTests {
    private let policy = ReviewRequestPolicy.standard
    private let day: TimeInterval = 24 * 60 * 60

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ dayIndex: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(dayIndex) * day)
    }

    private func readyState(nowDay: Int = 3) -> ReviewRequestPolicy.State {
        var state = ReviewRequestPolicy.State()
        for activeDay in (nowDay - 2)...nowDay {
            policy.recordActiveDay(
                in: &state,
                now: date(activeDay),
                calendar: calendar
            )
        }
        return state
    }

    private func opportunity(
        trigger: ReviewRequestTrigger = .storyClear,
        completions: Int = 6,
        onboardingCompleted: Bool = true,
        isFirstCompletion: Bool = true,
        stars: Int = 2,
        hasUsedRevive: Bool = false,
        showedResourceOffer: Bool = false,
        streakDays: Int = 0
    ) -> ReviewRequestOpportunity {
        ReviewRequestOpportunity(
            trigger: trigger,
            completedStoryLevelsAfterOnboarding: completions,
            onboardingCompleted: onboardingCompleted,
            isFirstCompletion: isFirstCompletion,
            stars: stars,
            hasUsedRevive: hasUsedRevive,
            showedResourceOffer: showedResourceOffer,
            streakDays: streakDays
        )
    }

    @Test func activeDaysAreDistinctCalendarDates() {
        var state = ReviewRequestPolicy.State()
        policy.recordActiveDay(in: &state, now: date(1), calendar: calendar)
        policy.recordActiveDay(in: &state, now: date(1) + 3_600, calendar: calendar)
        policy.recordActiveDay(in: &state, now: date(2), calendar: calendar)

        #expect(state.activeDays.count == 2)
        #expect(!policy.isEligible(
            for: opportunity(),
            state: state,
            now: date(2),
            appVersion: "1.0"
        ))
    }

    @Test func storyClearRequiresMaturePositiveFirstCompletion() {
        let state = readyState()

        #expect(!policy.isEligible(
            for: opportunity(completions: 5),
            state: state,
            now: date(3),
            appVersion: "1.0"
        ))
        #expect(!policy.isEligible(
            for: opportunity(onboardingCompleted: false),
            state: state,
            now: date(3),
            appVersion: "1.0"
        ))
        #expect(!policy.isEligible(
            for: opportunity(isFirstCompletion: false),
            state: state,
            now: date(3),
            appVersion: "1.0"
        ))
        #expect(!policy.isEligible(
            for: opportunity(stars: 1),
            state: state,
            now: date(3),
            appVersion: "1.0"
        ))
        #expect(policy.isEligible(
            for: opportunity(),
            state: state,
            now: date(3),
            appVersion: "1.0"
        ))
    }

    @Test func reviveAndResourceOffersBlockTheRequest() {
        let state = readyState()

        #expect(!policy.isEligible(
            for: opportunity(hasUsedRevive: true),
            state: state,
            now: date(3),
            appVersion: "1.0"
        ))
        #expect(!policy.isEligible(
            for: opportunity(showedResourceOffer: true),
            state: state,
            now: date(3),
            appVersion: "1.0"
        ))
    }

    @Test func frequencyIsOnePerVersionWithCooldownAndRollingCap() {
        var state = readyState()
        let first = date(3)
        policy.recordAttempt(
            for: .storyClear,
            in: &state,
            now: first,
            appVersion: "1.0"
        )

        #expect(!policy.isEligible(
            for: opportunity(),
            state: state,
            now: first + day,
            appVersion: "1.0"
        ))
        #expect(!policy.isEligible(
            for: opportunity(),
            state: state,
            now: first + 119 * day,
            appVersion: "1.1"
        ))

        let second = first + 120 * day
        #expect(policy.isEligible(
            for: opportunity(),
            state: state,
            now: second,
            appVersion: "1.1"
        ))
        policy.recordAttempt(
            for: .storyClear,
            in: &state,
            now: second,
            appVersion: "1.1"
        )

        #expect(!policy.isEligible(
            for: opportunity(),
            state: state,
            now: second + 120 * day,
            appVersion: "1.0"
        ))

        #expect(!policy.isEligible(
            for: opportunity(),
            state: state,
            now: second + 120 * day,
            appVersion: "1.2"
        ))

        let afterWindow = first + 366 * day
        for activeDay in 364...366 {
            policy.recordActiveDay(
                in: &state,
                now: date(activeDay + 3),
                calendar: calendar
            )
        }
        #expect(policy.isEligible(
            for: opportunity(),
            state: state,
            now: afterWindow,
            appVersion: "1.2"
        ))
    }

    @Test func photoMazeAndStreakAreUsedOnlyOnce() {
        var photoState = readyState()
        let photo = opportunity(trigger: .photoMazeCompleted)
        #expect(policy.isEligible(
            for: photo,
            state: photoState,
            now: date(3),
            appVersion: "1.0"
        ))
        policy.recordAttempt(
            for: .photoMazeCompleted,
            in: &photoState,
            now: date(3),
            appVersion: "1.0"
        )
        for activeDay in 367...369 {
            policy.recordActiveDay(
                in: &photoState,
                now: date(activeDay),
                calendar: calendar
            )
        }
        #expect(!policy.isEligible(
            for: photo,
            state: photoState,
            now: date(369),
            appVersion: "2.0"
        ))

        var streakState = readyState()
        #expect(!policy.isEligible(
            for: opportunity(trigger: .threeDayStreak, streakDays: 2),
            state: streakState,
            now: date(3),
            appVersion: "1.0"
        ))
        #expect(policy.isEligible(
            for: opportunity(trigger: .threeDayStreak, streakDays: 3),
            state: streakState,
            now: date(3),
            appVersion: "1.0"
        ))
        policy.recordAttempt(
            for: .threeDayStreak,
            in: &streakState,
            now: date(3),
            appVersion: "1.0"
        )
        for activeDay in 367...369 {
            policy.recordActiveDay(
                in: &streakState,
                now: date(activeDay),
                calendar: calendar
            )
        }
        #expect(!policy.isEligible(
            for: opportunity(trigger: .threeDayStreak, streakDays: 10),
            state: streakState,
            now: date(369),
            appVersion: "2.0"
        ))
    }
}
