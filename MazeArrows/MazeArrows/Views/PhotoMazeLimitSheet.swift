//
//  PhotoMazeLimitSheet.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct PhotoMazeLimitSheet: View {
    let theme: GameTheme
    let isAdReady: Bool
    let isPresentingAd: Bool
    let watchAd: () -> Void
    let openPremium: () -> Void
    let notNow: () -> Void

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .scaledFont(size: 34, weight: .bold)
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 76, height: 76)
                        .background(theme.primaryGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .accessibilityHidden(true)

                    Text("Free Photo Maze limit reached")
                        .scaledFont(size: 27, weight: .black, design: .rounded)
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("You’ve created your 5 free Photo Mazes. Watch one ad for another, or unlock unlimited creations with Premium.")
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundStyle(theme.inkSoft)
                        .multilineTextAlignment(.center)

                    watchAdButton

                    PrimaryButton(text: "Unlimited Photo Mazes with Premium", theme: theme, action: openPremium)

                    GhostButton(text: "Not now", theme: theme, action: notNow)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
    }

    private var watchAdButton: some View {
        Button(action: watchAd) {
            DynamicTypeStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Watch ad")
                        .textCase(.uppercase)
                        .scaledFont(size: 16, weight: .heavy)
                    Text("Create 1 Photo Maze")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundStyle(theme.inkSoft)
                }
                Spacer(minLength: 8)
                if isPresentingAd {
                    ProgressView()
                        .tint(theme.accent)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .scaledFont(size: 22, weight: .bold)
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(theme.accent.opacity(0.55), lineWidth: 1.5)
                    }
            )
            .minimumTapTarget()
        }
        .buttonStyle(.plain)
        .disabled(!isAdReady || isPresentingAd)
        .opacity(isAdReady || isPresentingAd ? 1 : 0.55)
        .accessibilityLabel("Watch ad")
        .accessibilityValue("Create 1 Photo Maze")
        .overlay(alignment: .bottom) {
            if !isAdReady && !isPresentingAd {
                Text("An ad isn’t available right now.")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(theme.inkMuted)
                    .offset(y: 20)
            }
        }
        .padding(.bottom, !isAdReady && !isPresentingAd ? 18 : 0)
    }
}
