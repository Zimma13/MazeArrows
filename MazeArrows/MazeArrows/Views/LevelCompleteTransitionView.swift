//
//  LevelCompleteTransitionView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

/// Brief input-free pause before an eligible interstitial. It prevents rapid
/// gameplay taps from landing on a newly presented full-screen ad.
struct LevelCompleteTransitionView: View {
    let theme: GameTheme

    var body: some View {
        ZStack {
            theme.appBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .scaledFont(size: 54, weight: .bold)
                    .foregroundStyle(theme.success)
                    .accessibilityHidden(true)

                Text("Cleared!")
                    .scaledFont(size: 42, weight: .black)
                    .foregroundStyle(theme.ink)

                ProgressView()
                    .controlSize(.large)
                    .tint(theme.accent)
                    .accessibilityHidden(true)

                Text("Preparing…")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(theme.inkMuted)
            }
            .accessibilityElement(children: .combine)
        }
        .accessibilityAddTraits(.isModal)
    }
}
