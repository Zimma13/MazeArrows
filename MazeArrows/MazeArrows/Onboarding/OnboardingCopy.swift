//
//  OnboardingCopy.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

enum OnboardingCopy {
    static let skip = text("onboarding.action.skip", "Skip")
    static let continueAction = text("onboarding.action.continue", "Continue")
    static let notNow = text("onboarding.action.not_now", "Not now")
    static let yesRemind = text("onboarding.action.yes_remind", "Yes, remind me")

    static let tapArrow = text("onboarding.tutorial.tap_arrow", "Tap the arrow")
    static let great = text("onboarding.tutorial.great", "Nice!")
    static let pathBlocked = text("onboarding.tutorial.path_blocked", "Path blocked")
    static let freePathFirst = text("onboarding.tutorial.free_path_first", "Clear the path first")
    static let hintShowsMove = text("onboarding.tutorial.hint", "Hints show the way")
    static let combo = text("onboarding.tutorial.combo", "Chain Clear!")
    static let livesRule = text(
        "onboarding.tutorial.lives_rule",
        "3 lives. Tapping a blocked path costs 1 life"
    )

    static let oneDay = text("onboarding.streak.one_day", "1 day")
    static let firstStreakDay = text("onboarding.streak.title", "Day 1 of your streak!")
    static let starterGift = text("onboarding.streak.gift", "+25 · starter gift")
    static let firstSteps = text("onboarding.streak.first_steps", "First steps")
    static var fortyPercent: String {
        0.4.formatted(.percent.precision(.fractionLength(0)))
    }
    static let firstFlight = text("onboarding.streak.first_flight", "First flight")
    static let firstCombo = text("onboarding.streak.first_combo", "First combo")
    static let clearLevelFive = text("onboarding.streak.level_five", "Clear level 5")
    static let playDailyMaze = text("onboarding.streak.daily", "Play the daily maze")
    static let returnTomorrow = text("onboarding.streak.tomorrow", "Come back tomorrow")
    static let streakContinues = text(
        "onboarding.streak.continues",
        "Your day streak will continue"
    )
    static let claimGift = text("onboarding.streak.claim", "Claim gift")

    static let pushTitle = text(
        "onboarding.push.title",
        "Daily maze + your streak — want a reminder?"
    )
    static let pushBody = text(
        "onboarding.push.body",
        "One quiet notification a day. No spam."
    )

    static let chooseStyle = text("onboarding.theme.title", "Pick your style")
    static let themeApplies = text(
        "onboarding.theme.subtitle",
        "The theme applies instantly. This is your board."
    )
    static let auroraDescription = text("onboarding.theme.aurora", "Soft and bright")
    static let neonDescription = text("onboarding.theme.neon", "Dark neon")
    static let petalDescription = text("onboarding.theme.petal", "Gentle pastel")
    static let auroraName = text("onboarding.theme.aurora_name", "Aurora Light")
    static let neonName = text("onboarding.theme.neon_name", "Midnight Neon")
    static let petalName = text("onboarding.theme.petal_name", "Petal Pastel")
    static let later = text("onboarding.theme.later", "Later")

    static func themeName(_ id: AppThemeID) -> String {
        switch id {
        case .aurora: auroraName
        case .neon: neonName
        case .petal: petalName
        default: id.displayName
        }
    }

    static let onARoll = text("onboarding.handoff.title", "You're on a roll")
    static let fourLevelsCleared = text(
        "onboarding.handoff.progress",
        "4 levels cleared"
    )
    static let chapterTwoLocked = text(
        "onboarding.handoff.chapter",
        "Chapter 2 is visible but locked. Finish Chapter 1 to open it."
    )
    static let goToLevelFive = text(
        "onboarding.handoff.level_five",
        "Next → Level 5"
    )
    static let worldMap = text("onboarding.handoff.world_map", "World map")

    static func levelNumber(_ level: Int) -> String {
        text("onboarding.tutorial.level_number", "Level \(level)")
    }

    static func livesCount(_ count: Int) -> String {
        text("onboarding.accessibility.lives_count", "\(count) lives remaining")
    }

    static func arrowAccessibility(_ id: String, _ direction: String) -> String {
        text(
            "onboarding.accessibility.arrow",
            "Arrow \(id), points \(direction)"
        )
    }

    static let arrowFreeAccessibility = text(
        "onboarding.accessibility.arrow_free",
        "Path is clear. Double-tap to launch."
    )
    static let arrowBlockedAccessibility = text(
        "onboarding.accessibility.arrow_blocked",
        "Path is blocked. Find the blocking arrow first."
    )
    static func directionName(_ direction: Direction) -> String {
        switch direction {
        case .up: text("onboarding.direction.up", "up")
        case .down: text("onboarding.direction.down", "down")
        case .left: text("onboarding.direction.left", "left")
        case .right: text("onboarding.direction.right", "right")
        }
    }

    private static func text(
        _ key: StaticString,
        _ defaultValue: String.LocalizationValue
    ) -> String {
        String(
            localized: key,
            defaultValue: defaultValue,
            table: "Onboarding",
            bundle: .main
        )
    }
}
