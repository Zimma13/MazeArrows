//
//  WinOverlayView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct WinOverlayView: View {
    let model: GameViewModel
    let theme: GameTheme
    let onReplay: () -> Void
    let onClose: () -> Void
    let onNext: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            theme.appBackground
                .ignoresSafeArea()
                .opacity(0.95)

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 24)
                        Text(levelLabel)
                            .textCase(.uppercase)
                            .scaledFont(size: 12, weight: .heavy)
                            .tracking(1.5)
                            .foregroundStyle(theme.inkMuted)
                            .accessibilityHidden(true)
                        Text("Cleared!")
                            .scaledFont(size: 56, weight: .black)
                            .foregroundStyle(theme.ink)
                            .accessibilityLabel(Text("\(levelLabel) cleared"))
                            .accessibilityAddTraits(.isHeader)

                        StarsRow(stars: model.earnedStars, theme: theme)
                            .padding(.top, 6)

                        statsCard
                            .padding(.horizontal, 24)
                            .padding(.top, 4)

                        if model.completionCoinReward > 0 {
                            coinPill
                        }
                        Spacer(minLength: 16)

                        VStack(spacing: 10) {
                            if let onNext {
                                PrimaryButton(text: "Next level", theme: theme, action: onNext)
                            }
                            DynamicTypeStack(spacing: 10) {
                                GhostButton(text: "Replay", theme: theme, action: onReplay)
                                GhostButton(text: "Close", theme: theme, action: onClose)
                            }
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

    private var levelLabel: String {
        switch model.mode {
        case .story(let i):    return String(localized: "Level \(i)")
        case .daily:           return String(localized: "Daily")
        case .weekly(let w):   return String(localized: "Weekly · \(w)")
        case .generated:       return String(localized: "Custom")
        case .zen(_, let i):   return String(localized: "Zen · \(i + 1)")
        case .master(let i):   return String(localized: "Level \(i) · Master")
        }
    }

    @ViewBuilder
    private var statsCard: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 14) {
                statItem(label: "Time", value: model.formattedTime)
                Divider().overlay(theme.glassBorder)
                statItem(label: "Moves", value: "\(model.movesMade)")
                Divider().overlay(theme.glassBorder)
                statItem(label: "Hints used", value: "\(model.hintsUsed)")
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(statsBackground)
        } else {
            HStack {
                statItem(label: "Time", value: model.formattedTime)
                divider
                statItem(label: "Moves", value: "\(model.movesMade)")
                divider
                statItem(label: "Hints used", value: "\(model.hintsUsed)")
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(statsBackground)
        }
    }

    private var statsBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(theme.glassBorder)
            )
    }

    private func statItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .scaledFont(size: 24, weight: .heavy)
                .foregroundStyle(theme.ink)
            Text(label)
                .textCase(.uppercase)
                .scaledFont(size: 11, weight: .heavy)
                .tracking(1)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.glassBorder)
            .frame(width: 1)
            .frame(height: 32)
    }

    private var coinPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .foregroundStyle(theme.achievementGold)
                .scaledFont(size: 16)
            Text("+\(model.completionCoinReward)")
                .scaledFont(size: 16, weight: .heavy)
                .foregroundStyle(Color(red: 0.48, green: 0.33, blue: 0.06))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(red: 1, green: 0.96, blue: 0.85),
                             Color(red: 1, green: 0.9, blue: 0.6)],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coin reward")
        .accessibilityValue(Text("\(model.completionCoinReward) coins"))
    }
}

struct StarsRow: View {
    let stars: Int
    let theme: GameTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func dimGradient(theme: GameTheme) -> LinearGradient {
        let muted = theme.inkMuted
        return LinearGradient(colors: [muted, muted], startPoint: .top, endPoint: .bottom)
    }

    private func goldGradient(theme: GameTheme) -> LinearGradient {
        LinearGradient(
            colors: [theme.achievementGold, theme.achievementGold],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                starImage(at: i)
            }
        }
        .frame(minHeight: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stars earned")
        .accessibilityValue(Text("\(stars) of 3"))
    }

    @ViewBuilder
    private func starImage(at i: Int) -> some View {
        let earned = i < stars
        let image = Image(systemName: earned ? "star.fill" : "star")
            .scaledFont(size: i == 1 ? 44 : 36, weight: .black)
            .foregroundStyle(earned ? goldGradient(theme: theme) : dimGradient(theme: theme))
            .offset(y: i == 1 ? -8 : 0)
            .scaleEffect(earned ? 1.0 : 0.9)
        if reduceMotion {
            image
        } else {
            image.symbolEffect(.bounce, value: stars)
        }
    }
}

struct PrimaryButton: View {
    let text: LocalizedStringKey
    let theme: GameTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .textCase(.uppercase)
                .scaledFont(size: 18, weight: .heavy)
                .tracking(0.5)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(theme.primaryGradient)
                        .shadow(color: theme.primaryShadow.opacity(0.5), radius: 14, x: 0, y: 6)
                )
                .minimumTapTarget()
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let text: LocalizedStringKey
    let systemImage: String?
    let theme: GameTheme
    let prominence: ThemedGlassProminence
    let action: () -> Void

    init(
        text: LocalizedStringKey,
        systemImage: String? = nil,
        theme: GameTheme,
        prominence: ThemedGlassProminence = .compact,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.systemImage = systemImage
        self.theme = theme
        self.prominence = prominence
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(text)
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
            }
            .textCase(.uppercase)
            .scaledFont(size: 14, weight: .bold)
            .foregroundStyle(theme.ink)
            .artworkLegibility(
                theme: theme,
                isEnabled: prominence == .transparent || prominence == .interactiveGlass
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .themedGlass(theme: theme, in: Capsule(), prominence: prominence)
            .contentShape(Capsule())
            .minimumTapTarget()
        }
        .buttonStyle(.plain)
    }
}
