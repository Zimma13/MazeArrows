//
//  PremiumAccessPolicy.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

struct PremiumAccessPolicy: Equatable, Sendable {
    static let free = PremiumAccessPolicy(isPremium: false)
    static let premium = PremiumAccessPolicy(isPremium: true)

    let isPremium: Bool

    var hasUnlimitedPhotoMaze: Bool { isPremium }
    var hasUnlimitedHints: Bool { isPremium }

    func canUseTheme(_ id: AppThemeID) -> Bool {
        isPremium || !id.requiresPremium
    }

    func resolvedTheme(_ requested: AppThemeID) -> AppThemeID {
        canUseTheme(requested) ? requested : .aurora
    }
}

extension AppThemeID {
    var requiresPremium: Bool {
        switch self {
        case .aurora, .neon, .petal:
            false
        case .sakura, .atlas, .nordic:
            true
        }
    }
}
