//
//  PremiumAccessPolicyTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Testing
@testable import MazeArrows

struct PremiumAccessPolicyTests {
    @Test func freeAccessKeepsCoreThemesAndLocksPremiumFeatures() {
        let access = PremiumAccessPolicy.free

        #expect(!access.hasUnlimitedPhotoMaze)
        #expect(!access.hasUnlimitedHints)
        #expect(access.canUseTheme(.aurora))
        #expect(access.canUseTheme(.neon))
        #expect(access.canUseTheme(.petal))
        #expect(!access.canUseTheme(.sakura))
        #expect(!access.canUseTheme(.atlas))
        #expect(!access.canUseTheme(.nordic))
        #expect(access.resolvedTheme(.sakura) == .aurora)
    }

    @Test func premiumAccessUnlocksEveryDeclaredBenefit() {
        let access = PremiumAccessPolicy.premium

        #expect(access.hasUnlimitedPhotoMaze)
        #expect(access.hasUnlimitedHints)
        for theme in AppThemeID.allCases {
            #expect(access.canUseTheme(theme))
            #expect(access.resolvedTheme(theme) == theme)
        }
    }
}
