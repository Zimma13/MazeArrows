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
    static let close = text("onboarding.action.close", "Close")
    static let continueAction = text("onboarding.action.continue", "Continue")
    static let next = text("onboarding.action.next", "Next")
    static let notNow = text("onboarding.action.not_now", "Not now")
    static let yesRemind = text("onboarding.action.yes_remind", "Yes, remind me")
    static let premium = text("onboarding.common.premium", "Premium")
    static let ok = text("onboarding.action.ok", "OK")

    static func pageProgress(_ current: Int, of total: Int) -> String {
        text("onboarding.accessibility.page_progress", "\(current) of \(total)")
    }

    static let tapArrow = text("onboarding.tutorial.tap_arrow", "Tap the arrow")
    static let great = text("onboarding.tutorial.great", "Nice!")
    static let pathBlocked = text("onboarding.tutorial.path_blocked", "Path blocked")
    static let freePathFirst = text("onboarding.tutorial.free_path_first", "Clear the path first")
    static let hintShowsMove = text("onboarding.tutorial.hint", "Hints show the way")
    static let hintsThree = text("onboarding.tutorial.hints_three", "Hints: 3")
    static let combo = text("onboarding.tutorial.combo", "Chain Clear!")
    static let livesRule = text(
        "onboarding.tutorial.lives_rule",
        "3 lives. Tapping a blocked path costs 1 life"
    )

    static let playWithoutLimits = text("onboarding.paywall.intro.title", "Play without limits")
    static let anyPhotoMaze = text("onboarding.paywall.intro.photo_title", "Any photo. A maze.")
    static let unlimitedHints = text(
        "onboarding.paywall.intro.hints",
        "Unlimited hints"
    )
    static let turnAnyPhoto = text(
        "onboarding.paywall.intro.photo_benefit",
        "Turn any photo into a maze"
    )
    static let unlimitedPhotoMazes = text(
        "onboarding.paywall.intro.photo_unlimited",
        "Unlimited Photo Maze creations"
    )
    static let noAds = text("onboarding.paywall.intro.no_ads", "No ads")
    static let choosePlan = text("onboarding.paywall.plans.title", "Choose a plan")
    static let week = text("onboarding.paywall.plans.week", "Week")
    static let year = text("onboarding.paywall.plans.year", "Year")

    static func weeklyPrice(_ price: String) -> String {
        text("onboarding.paywall.plans.weekly_price", "\(price)/week")
    }

    static func annualPrice(_ price: String) -> String {
        text("onboarding.paywall.plans.annual_price", "\(price)/year")
    }

    static func annualPerWeek(_ price: String) -> String {
        text(
            "onboarding.paywall.plans.annual_per_week",
            "≈ \(price)/week"
        )
    }

    static func planPriceLine(_ primary: String, _ secondary: String) -> String {
        text(
            "onboarding.paywall.plans.price_line",
            "\(primary) · \(secondary)"
        )
    }

    static func savings(_ percent: Int) -> String {
        let formattedPercent = (Double(percent) / 100).formatted(
            .percent.precision(.fractionLength(0))
        )
        return text("onboarding.paywall.plans.savings", "Save \(formattedPercent)")
    }

    static let subscribeWeekly = text(
        "onboarding.paywall.plans.weekly_cta",
        "Start weekly Premium"
    )

    static func subscribeAnnual(_ price: String) -> String {
        text("onboarding.paywall.plans.annual_cta", "Get a year for \(price)")
    }

    static func chargedTodayBillingSubtitle(_ price: String, _ date: String) -> String {
        text(
            "onboarding.paywall.plans.annual_billing",
            "\(price) charged today · Renews \(date)"
        )
    }

    static let restore = text("onboarding.paywall.restore", "Restore purchases")
    static let manageSubscription = text(
        "onboarding.paywall.manage_subscription",
        "Manage subscription"
    )
    static let autoRenewalDisclosure = text(
        "onboarding.paywall.auto_renewal",
        "Subscription renews automatically until canceled."
    )
    static let terms = text("onboarding.paywall.terms", "Terms of Use")
    static let privacy = text("onboarding.paywall.privacy", "Privacy Policy")
    static let purchasePending = text(
        "onboarding.paywall.purchase_pending",
        "Purchase is waiting for approval"
    )
    static let purchaseFailed = text(
        "onboarding.paywall.purchase_failed",
        "Purchase couldn't be completed. Please try again."
    )
    static let restoreFailed = text(
        "onboarding.paywall.restore_failed",
        "Purchases couldn't be restored. Please try again."
    )
    static let nothingToRestore = text(
        "onboarding.paywall.nothing_to_restore",
        "No active Premium purchase was found."
    )
    static let restored = text("onboarding.paywall.restored", "Premium restored")
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
    static let morePremiumThemes = text(
        "onboarding.theme.more",
        "3 more themes in Premium"
    )
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
    static let directionUp = text("onboarding.direction.up", "up")
    static let directionDown = text("onboarding.direction.down", "down")
    static let directionLeft = text("onboarding.direction.left", "left")
    static let directionRight = text("onboarding.direction.right", "right")

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
