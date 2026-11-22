//
//  ResourceOfferSheet.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct ResourceOfferSheet: View {
    let model: GameViewModel
    let offer: GameViewModel.ResourceOffer
    let theme: GameTheme
    let onRetry: () -> Void
    let onClose: () -> Void

    private var price: Int { model.price(for: offer) }
    private var canAfford: Bool { model.canAfford(offer) }
    private var shortfall: Int { max(0, price - model.coinBalance) }

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                        .padding(.top, 28)

                    CoinBalanceChip(coins: model.coinBalance, theme: theme)

                    VStack(spacing: 10) {
                        coinSlot
                        if !canAfford {
                            GhostButton(text: "Retry", theme: theme, action: onRetry)
                            GhostButton(text: "Back to levels", theme: theme, action: onClose)
                        }
                        GhostButton(text: "Not now", theme: theme) {
                            model.dismissResourceOffer()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(theme.surface)
                    .overlay(Circle().stroke(theme.glassBorder))
                    .frame(width: 74, height: 74)
                Image(systemName: iconName)
                    .scaledFont(size: 32, weight: .bold)
                    .foregroundStyle(theme.accent)
            }
            .accessibilityHidden(true)

            Text(title)
                .scaledFont(size: 26, weight: .black)
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .scaledFont(size: 14, weight: .medium)
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var iconName: String {
        switch offer {
        case .undo:   return "arrow.uturn.backward"
        case .revive: return "heart.fill"
        }
    }

    private var title: LocalizedStringKey {
        switch offer {
        case .undo:   return "Out of undos"
        case .revive: return "Keep going?"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch offer {
        case .undo:   return "An undo brings back the last cleared arrow."
        case .revive: return "Continue this level right where you left off."
        }
    }

    private var coinSlot: some View {
        VStack(spacing: 6) {
            Button {
                model.purchaseOfferedResource()
            } label: {
                DynamicTypeStack(spacing: 8) {
                    Text(buyLabel)
                        .textCase(.uppercase)
                        .scaledFont(size: 16, weight: .heavy)
                        .tracking(0.5)
                    Spacer(minLength: 8)
                    CoinPriceTag(price: price, affordable: canAfford, theme: theme)
                }
                .foregroundStyle(canAfford ? theme.primaryText : theme.inkMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(canAfford ? AnyShapeStyle(theme.primaryGradient) : AnyShapeStyle(theme.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(canAfford ? .clear : theme.glassBorder, lineWidth: 1.5)
                        )
                )
                .minimumTapTarget()
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
            .accessibilityLabel(Text(buyLabel))
            .accessibilityValue(Text("\(price) coins"))
            .accessibilityHint(canAfford ? Text(verbatim: "") : Text("Not enough coins."))

            if !canAfford {
                Text("Not enough coins — \(shortfall) more needed")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    private var buyLabel: LocalizedStringKey {
        switch offer {
        case .undo:   return "Get 1 undo"
        case .revive: return "Continue · +\(model.economyConfig.reviveLives) lives"
        }
    }
}

// MARK: - shared coin components

struct CoinBalanceChip: View {
    let coins: Int
    let theme: GameTheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .scaledFont(size: 13)
                .foregroundStyle(theme.achievementGold)
            Text("\(coins)")
                .scaledFont(size: 14, weight: .heavy)
                .foregroundStyle(theme.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .themedGlass(theme: theme, in: Capsule(), prominence: .compact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coins")
        .accessibilityValue(Text("\(coins)"))
    }
}

struct CoinPriceTag: View {
    let price: Int
    let affordable: Bool
    let theme: GameTheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .scaledFont(size: 11)
                .foregroundStyle(affordable ? theme.achievementGold : theme.inkMuted)
            Text("\(price)")
                .scaledFont(size: 14, weight: .heavy)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(.black.opacity(affordable ? 0.18 : 0.06))
        )
        .accessibilityHidden(true)
    }
}
