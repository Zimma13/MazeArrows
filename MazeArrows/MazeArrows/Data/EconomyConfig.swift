//
//  EconomyConfig.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Central knobs for the coin economy. Values ship as compile-time defaults;
//  the monetization plan later swaps the provider for a remote-config-backed
//  one without touching call sites.
//

import Foundation

struct EconomyConfig: Equatable, Sendable {
    /// Coin price of one hint.
    var hintCost = 100
    /// Coin price of one undo.
    var undoCost = 30
    /// Coin price of continuing a failed level.
    var reviveCost = 150
    /// Lives restored by a revive.
    var reviveLives = 2
    /// Coin price of one streak freeze.
    var streakFreezeCost = 250
    /// Maximum streak freezes a player can hold at once.
    var maxStreakFreezes = 2
    /// Free Zen levels per UTC day.
    var zenFreeLevelsPerDay = 3
    /// One-time coin reward for clearing a level with a master modifier.
    var masterClearReward = 25
    /// Streak milestone chests: consecutive daily-puzzle days → coins.
    var streakChests: [Int: Int] = [3: 50, 7: 100, 14: 200, 30: 400]
    /// Coins for the once-a-day rewarded-ad bonus (inactive until ads land).
    var rewardedDailyBonus = 50
    /// Automatic daily coin reward for premium (inactive until entitlements land).
    var premiumDailyReward = 125

    static let `default` = EconomyConfig()
}

@MainActor
protocol EconomyConfigProviding: AnyObject {
    var config: EconomyConfig { get }
}

@MainActor
final class EconomyConfigStore: EconomyConfigProviding {
    static let shared = EconomyConfigStore()

    private(set) var config: EconomyConfig

    init(base: EconomyConfig = .default, defaults: UserDefaults = .standard) {
        #if DEBUG
        config = Self.applyingDebugOverrides(to: base, defaults: defaults)
        #else
        config = base
        #endif
    }

    #if DEBUG
    /// Override keys follow "economy.<field>", so a value can be forced from
    /// the scheme with a launch argument like "-economy.hintCost 50".
    static func applyingDebugOverrides(
        to base: EconomyConfig,
        defaults: UserDefaults
    ) -> EconomyConfig {
        var config = base
        func apply(_ key: String, _ value: inout Int) {
            guard defaults.object(forKey: "economy.\(key)") != nil else { return }
            let override = defaults.integer(forKey: "economy.\(key)")
            if override > 0 { value = override }
        }
        apply("hintCost", &config.hintCost)
        apply("undoCost", &config.undoCost)
        apply("reviveCost", &config.reviveCost)
        apply("reviveLives", &config.reviveLives)
        apply("streakFreezeCost", &config.streakFreezeCost)
        apply("maxStreakFreezes", &config.maxStreakFreezes)
        apply("zenFreeLevelsPerDay", &config.zenFreeLevelsPerDay)
        apply("masterClearReward", &config.masterClearReward)
        apply("rewardedDailyBonus", &config.rewardedDailyBonus)
        apply("premiumDailyReward", &config.premiumDailyReward)
        return config
    }
    #endif
}
