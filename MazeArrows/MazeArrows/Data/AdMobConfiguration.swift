//
//  AdMobConfiguration.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

/// AdMob identifiers are public routing identifiers, not credentials.
/// Debug builds always use Google's demo inventory so development activity
/// can never be counted as production traffic.
struct AdMobConfiguration: Equatable, Sendable {
    let appID: String
    let interstitialLevelComplete: String
    let rewardedHint: String
    let rewardedUndo: String
    let rewardedRevive: String
    let rewardedPhotoMaze: String

    static let production = AdMobConfiguration(
        appID: "ca-app-pub-4288377893011444~6264190828",
        interstitialLevelComplete: "ca-app-pub-4288377893011444/2083855358",
        rewardedHint: "ca-app-pub-4288377893011444/1305126151",
        rewardedUndo: "ca-app-pub-4288377893011444/3017025049",
        rewardedRevive: "ca-app-pub-4288377893011444/9390861701",
        rewardedPhotoMaze: "ca-app-pub-4288377893011444/4138535022"
    )

    static let test = AdMobConfiguration(
        appID: "ca-app-pub-3940256099942544~1458002511",
        interstitialLevelComplete: "ca-app-pub-3940256099942544/4411468910",
        rewardedHint: "ca-app-pub-3940256099942544/1712485313",
        rewardedUndo: "ca-app-pub-3940256099942544/1712485313",
        rewardedRevive: "ca-app-pub-3940256099942544/1712485313",
        rewardedPhotoMaze: "ca-app-pub-3940256099942544/1712485313"
    )

    static var current: AdMobConfiguration {
        #if DEBUG
        .test
        #else
        .production
        #endif
    }
}
