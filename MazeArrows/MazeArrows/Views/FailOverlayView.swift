//
//  FailOverlayView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct FailOverlayView: View {
    let model: GameViewModel
    let theme: GameTheme
    let onRevive: () -> Void
    let onRetry: () -> Void
    let onClose: () -> Void

    private var totalPieces: Int { model.level.pieces.count }
    private var clearedPieces: Int { totalPieces - (model.scene?.board.pieces.count ?? 0) }

    var body: some View {
        ZStack {
            theme.appBackground
                .ignoresSafeArea()
                .opacity(0.95)

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 24)
                        Text(levelLabel)
                            .textCase(.uppercase)
                            .scaledFont(size: 12, weight: .heavy)
                            .tracking(1.5)
                            .foregroundStyle(theme.inkMuted)
                            .accessibilityHidden(true)
                        Text(failTitle)
                            .multilineTextAlignment(.center)
                            .scaledFont(size: 48, weight: .black)
                            .foregroundStyle(theme.ink)
                            .accessibilityLabel(Text("\(levelLabel) failed."))
                            .accessibilityAddTraits(.isHeader)

                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [theme.danger, theme.danger.opacity(0.7)],
                                        center: .topLeading, startRadius: 6, endRadius: 90
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .shadow(color: theme.danger.opacity(0.4), radius: 20, x: 0, y: 10)
                            Image(systemName: failIcon)
                                .scaledFont(size: 50, weight: .heavy)
                                .foregroundStyle(theme.textOnDanger)
                        }
                        .accessibilityHidden(true)

                        Text("You cleared **\(clearedPieces) of \(totalPieces)** pieces")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundStyle(theme.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(theme.surface)
                                    .overlay(Capsule().stroke(theme.glassBorder))
                            )

                        Spacer(minLength: 16)

                        VStack(spacing: 10) {
                            if model.canRevive {
                                reviveButton
                                GhostButton(text: "Retry", theme: theme, action: onRetry)
                            } else {
                                PrimaryButton(text: "Retry", theme: theme, action: onRetry)
                            }
                            GhostButton(text: "Back to levels", theme: theme, action: onClose)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var reviveButton: some View {
        Button(action: onRevive) {
            DynamicTypeStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .scaledFont(size: 15, weight: .heavy)
                Text("Continue · +\(model.economyConfig.reviveLives)")
                    .textCase(.uppercase)
                    .scaledFont(size: 17, weight: .heavy)
                    .tracking(0.5)
                Spacer(minLength: 8)
                CoinPriceTag(
                    price: model.price(for: .revive),
                    affordable: model.canAfford(.revive),
                    theme: theme
                )
            }
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(theme.primaryGradient)
                    .shadow(color: theme.primaryShadow.opacity(0.5), radius: 14, x: 0, y: 6)
            )
            .minimumTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Continue with \(model.economyConfig.reviveLives) lives"))
        .accessibilityValue(Text("\(model.price(for: .revive)) coins"))
    }

    private var failTitle: LocalizedStringKey {
        switch model.failReason {
        case .timeUp:               return "Time's\nup"
        case .goalFailed:           return "Goal\nmissed"
        case .outOfLives, .none:    return "Out of\nmoves"
        }
    }

    private var failIcon: String {
        switch model.failReason {
        case .timeUp:               return "timer"
        case .goalFailed:           return "target"
        case .outOfLives, .none:    return "heart.slash.fill"
        }
    }

    private var levelLabel: String {
        switch model.mode {
        case .story(let i):  return String(localized: "Level \(i)")
        case .daily:         return String(localized: "Daily")
        case .weekly:        return String(localized: "Weekly")
        case .generated:     return String(localized: "Custom")
        case .zen:           return String(localized: "Zen")
        case .master(let i): return String(localized: "Level \(i) · Master")
        }
    }
}
