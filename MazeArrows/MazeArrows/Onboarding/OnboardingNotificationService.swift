//
//  OnboardingNotificationService.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import UserNotifications

enum OnboardingNotificationService {
    private static let dailyIdentifier = "MazeArrows.dailyReminder"

    @discardableResult
    static func requestDailyReminder() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }

            center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Daily maze is ready", table: "Onboarding")
            content.body = String(localized: "Keep your streak alive with one quick maze.", table: "Onboarding")
            content.sound = .default

            var components = DateComponents()
            components.hour = 19
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try await center.add(UNNotificationRequest(
                identifier: dailyIdentifier,
                content: content,
                trigger: trigger
            ))
            return true
        } catch {
            return false
        }
    }

}
