//
//  Analytics.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Typed economy events, wired now so funnels exist from day one. The client
//  is a no-op until an analytics SDK lands (stage 13 of the monetization
//  plan) — swapping `Analytics.client` is the only integration point.
//

import Foundation

enum AnalyticsEvent: Equatable, Sendable {
    case appLaunch
    case initialScreenReady(screen: String, durationMilliseconds: Int)
    case menuReady
    case gameCenterAuthenticationStarted
    case gameCenterAuthenticated(
        isUnderage: Bool,
        isMultiplayerRestricted: Bool,
        isCommunicationRestricted: Bool
    )
    case gameCenterAuthenticationFailed(reason: String)
    case gameCenterLeaderboardSubmitted(identifier: String, score: Int)
    case gameCenterLeaderboardSubmissionFailed(identifier: String, reason: String)
    case gameCenterAchievementsSubmitted(count: Int)
    case gameCenterAchievementSubmissionFailed(count: Int, reason: String)
    case playTapped(levelIndex: Int)
    case levelLoadStarted(contentID: String, mode: String)
    case levelReady(contentID: String, mode: String, durationMilliseconds: Int)
    case levelStarted(contentID: String, mode: String)
    case levelCompleted(
        contentID: String,
        mode: String,
        durationSeconds: Int,
        mistakes: Int,
        hintsUsed: Int,
        maxCombo: Int
    )
    case levelFailed(
        contentID: String,
        mode: String,
        durationSeconds: Int,
        reason: String
    )
    case levelRestarted(contentID: String, mode: String)
    case coinsSpent(sink: String, amount: Int, balance: Int)
    case offerShown(context: String, slots: [String])
    case offerConverted(context: String, slot: String)
    case reviveOffered
    case reviveUsed
    case zenLevelStart(index: Int)
    case zenLimitHit
    case masterClear(levelIndex: Int, modifier: String)
    case streakFreezeUsed
    case streakChestClaimed(day: Int, coins: Int)
    case reviewRequestEligible(trigger: String)
    case reviewRequestAttempted(trigger: String)

    var name: String {
        switch self {
        case .appLaunch:         return "app_launch"
        case .initialScreenReady:return "initial_screen_ready"
        case .menuReady:         return "menu_ready"
        case .gameCenterAuthenticationStarted:
            return "game_center_authentication_started"
        case .gameCenterAuthenticated:
            return "game_center_authenticated"
        case .gameCenterAuthenticationFailed:
            return "game_center_authentication_failed"
        case .gameCenterLeaderboardSubmitted:
            return "game_center_leaderboard_submitted"
        case .gameCenterLeaderboardSubmissionFailed:
            return "game_center_leaderboard_submission_failed"
        case .gameCenterAchievementsSubmitted:
            return "game_center_achievements_submitted"
        case .gameCenterAchievementSubmissionFailed:
            return "game_center_achievement_submission_failed"
        case .playTapped:        return "play_tapped"
        case .levelLoadStarted:  return "level_load_started"
        case .levelReady:        return "level_ready"
        case .levelStarted:      return "level_started"
        case .levelCompleted:    return "level_completed"
        case .levelFailed:       return "level_failed"
        case .levelRestarted:    return "level_restarted"
        case .coinsSpent:         return "economy_coins_spent"
        case .offerShown:         return "economy_offer_shown"
        case .offerConverted:     return "economy_offer_converted"
        case .reviveOffered:      return "revive_offered"
        case .reviveUsed:         return "revive_used"
        case .zenLevelStart:      return "zen_level_start"
        case .zenLimitHit:        return "zen_limit_hit"
        case .masterClear:        return "master_clear"
        case .streakFreezeUsed:   return "streak_freeze_used"
        case .streakChestClaimed: return "streak_chest_claimed"
        case .reviewRequestEligible: return "review_request_eligible"
        case .reviewRequestAttempted: return "review_request_attempted"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .appLaunch, .menuReady, .gameCenterAuthenticationStarted:
            return [:]
        case .initialScreenReady(let screen, let durationMilliseconds):
            return [
                "screen": screen,
                "duration_ms": "\(durationMilliseconds)"
            ]
        case .playTapped(let levelIndex):
            return ["level": "\(levelIndex)"]
        case .gameCenterAuthenticated(
            let isUnderage,
            let isMultiplayerRestricted,
            let isCommunicationRestricted
        ):
            return [
                "underage": "\(isUnderage)",
                "multiplayer_restricted": "\(isMultiplayerRestricted)",
                "communication_restricted": "\(isCommunicationRestricted)"
            ]
        case .gameCenterAuthenticationFailed(let reason):
            return ["reason": reason]
        case .gameCenterLeaderboardSubmitted(let identifier, let score):
            return ["identifier": identifier, "score": "\(score)"]
        case .gameCenterLeaderboardSubmissionFailed(let identifier, let reason):
            return ["identifier": identifier, "reason": reason]
        case .gameCenterAchievementsSubmitted(let count):
            return ["count": "\(count)"]
        case .gameCenterAchievementSubmissionFailed(let count, let reason):
            return ["count": "\(count)", "reason": reason]
        case .levelLoadStarted(let contentID, let mode),
             .levelStarted(let contentID, let mode),
             .levelRestarted(let contentID, let mode):
            return ["content_id": contentID, "mode": mode]
        case .levelReady(let contentID, let mode, let durationMilliseconds):
            return [
                "content_id": contentID,
                "mode": mode,
                "duration_ms": "\(durationMilliseconds)"
            ]
        case .levelCompleted(
            let contentID,
            let mode,
            let durationSeconds,
            let mistakes,
            let hintsUsed,
            let maxCombo
        ):
            return [
                "content_id": contentID,
                "mode": mode,
                "duration_seconds": "\(durationSeconds)",
                "mistakes": "\(mistakes)",
                "hints_used": "\(hintsUsed)",
                "max_combo": "\(maxCombo)"
            ]
        case .levelFailed(let contentID, let mode, let durationSeconds, let reason):
            return [
                "content_id": contentID,
                "mode": mode,
                "duration_seconds": "\(durationSeconds)",
                "reason": reason
            ]
        case .coinsSpent(let sink, let amount, let balance):
            return ["sink": sink, "amount": "\(amount)", "balance": "\(balance)"]
        case .offerShown(let context, let slots):
            return ["context": context, "slots": slots.joined(separator: ",")]
        case .offerConverted(let context, let slot):
            return ["context": context, "slot": slot]
        case .reviveOffered, .reviveUsed, .zenLimitHit, .streakFreezeUsed:
            return [:]
        case .zenLevelStart(let index):
            return ["index": "\(index)"]
        case .masterClear(let levelIndex, let modifier):
            return ["level": "\(levelIndex)", "modifier": modifier]
        case .streakChestClaimed(let day, let coins):
            return ["day": "\(day)", "coins": "\(coins)"]
        case .reviewRequestEligible(let trigger),
             .reviewRequestAttempted(let trigger):
            return ["trigger": trigger]
        }
    }
}

@MainActor
protocol AnalyticsClient: AnyObject {
    func log(_ event: AnalyticsEvent)
}

@MainActor
final class NoopAnalyticsClient: AnalyticsClient {
    func log(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[analytics] \(event.name) \(event.parameters)")
        #endif
    }
}

@MainActor
enum Analytics {
    static var client: any AnalyticsClient = NoopAnalyticsClient()

    static func log(_ event: AnalyticsEvent) {
        client.log(event)
    }
}
