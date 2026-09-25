//
//  FeatureFlags.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Switches for surfaces that ship before their backing systems exist.
//

enum FeatureFlags {
    /// The onboarding paywall stays implemented but is temporarily skipped.
    static let onboardingPaywallAvailable = false
    /// Sharing and friend imports, including incoming links, stay disabled until V2.
    static let photoMazeSharingAvailable = false
    /// Non-rewarded ads shown only at scheduled campaign level breaks.
    static let interstitialAdsAvailable = true
    /// Opt-in rewarded ads for hints, undos and revives.
    static let adsAvailable = true
    /// Premium slots in offer sheets — enabled once entitlements land.
    static let premiumOffersEnabled = false
}
