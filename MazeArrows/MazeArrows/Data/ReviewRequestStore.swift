//
//  ReviewRequestStore.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import Observation

@MainActor
@Observable
final class ReviewRequestStore {
    struct Reservation: Equatable, Sendable {
        fileprivate let id: UUID
        let trigger: ReviewRequestTrigger
        fileprivate let appVersion: String
    }

    static let appStoreReviewURL = URL(
        string: "https://apps.apple.com/app/id6800708435?action=write-review"
    )!

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let policy: ReviewRequestPolicy
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let appVersionProvider: () -> String
    @ObservationIgnored private let persistenceKey = "MazeArrows.ReviewRequestState.v1"
    @ObservationIgnored private var state: ReviewRequestPolicy.State
    @ObservationIgnored private var pendingReservation: Reservation?

    init(
        defaults: UserDefaults = .standard,
        policy: ReviewRequestPolicy = .standard,
        calendar: Calendar = .current,
        appVersionProvider: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "unknown"
        }
    ) {
        self.defaults = defaults
        self.policy = policy
        self.calendar = calendar
        self.appVersionProvider = appVersionProvider

        if let data = defaults.data(forKey: persistenceKey),
           let decoded = try? JSONDecoder().decode(
               ReviewRequestPolicy.State.self,
               from: data
           ) {
            state = decoded
        } else {
            state = .init()
        }
    }

    func recordActiveDay(now: Date = .now) {
        policy.recordActiveDay(in: &state, now: now, calendar: calendar)
        persist()
    }

    func reserve(
        opportunity: ReviewRequestOpportunity,
        now: Date = .now
    ) -> Reservation? {
        guard pendingReservation == nil else { return nil }

        let appVersion = appVersionProvider()
        guard policy.isEligible(
            for: opportunity,
            state: state,
            now: now,
            appVersion: appVersion
        ) else { return nil }

        let reservation = Reservation(
            id: UUID(),
            trigger: opportunity.trigger,
            appVersion: appVersion
        )
        pendingReservation = reservation
        Analytics.log(.reviewRequestEligible(trigger: opportunity.trigger.rawValue))
        return reservation
    }

    func commit(_ reservation: Reservation, now: Date = .now) -> Bool {
        guard pendingReservation == reservation else { return false }
        pendingReservation = nil
        policy.recordAttempt(
            for: reservation.trigger,
            in: &state,
            now: now,
            appVersion: reservation.appVersion
        )
        persist()
        Analytics.log(.reviewRequestAttempted(trigger: reservation.trigger.rawValue))
        return true
    }

    func cancel(_ reservation: Reservation) {
        guard pendingReservation == reservation else { return }
        pendingReservation = nil
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: persistenceKey)
    }
}
