//
//  ComboHUDTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Testing
@testable import MazeArrows

@MainActor
struct ComboHUDTests {
    @Test func comboHUDStartsAtTwoConsecutiveMoves() {
        #expect(!GameViewModel.shouldPresentComboHUD(for: 0))
        #expect(!GameViewModel.shouldPresentComboHUD(for: 1))
        #expect(GameViewModel.shouldPresentComboHUD(for: 2))
        #expect(GameViewModel.shouldPresentComboHUD(for: 10))
    }

    @Test func allPreviewAnimationStylesRemainAvailable() {
        #expect(
            Set(ComboHUDAnimationStyle.allCases) == [
                .softSwap,
                .verticalCarousel,
                .flip,
                .capsuleMorph
            ]
        )
    }

    @Test func animationStyleRotatesAtEveryThirdCombo() {
        #expect(ComboHUDAnimationStyle.style(for: 2) == .capsuleMorph)
        #expect(ComboHUDAnimationStyle.style(for: 3) == .softSwap)
        #expect(ComboHUDAnimationStyle.style(for: 5) == .softSwap)
        #expect(ComboHUDAnimationStyle.style(for: 6) == .verticalCarousel)
        #expect(ComboHUDAnimationStyle.style(for: 9) == .flip)
        #expect(ComboHUDAnimationStyle.style(for: 12) == .capsuleMorph)
        #expect(ComboHUDAnimationStyle.style(for: 15) == .softSwap)
    }
}
