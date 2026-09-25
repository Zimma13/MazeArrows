//
//  AchievementsView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct AchievementsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progressStore
    @Environment(GameCenterStore.self) private var gameCenter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var summaryDiameter: CGFloat = 72

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }
    private var earned: Set<AchievementID> { progressStore.progress.earnedAchievements }

    private var categories: [Achievement.Category] { [.progress, .skill, .streak, .special] }

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    summaryHeader
                        .padding(.top, 8)

                    ForEach(categories, id: \.rawValue) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Achievements")
                    .scaledFont(size: 18, weight: .heavy)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            if gameCenter.isAuthenticated {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        gameCenter.presentGameCenter(.achievements)
                    } label: {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(theme.accent)
                    }
                    .accessibilityLabel("Game Center")
                    .accessibilityHint("Achievements")
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .designedBackButton(theme: theme)
        .edgeFades(theme: theme)
    }

    // MARK: - summary

    private var summaryHeader: some View {
        let total = Achievement.all.count
        let done = earned.count

        return DynamicTypeStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(theme.glassBorder, lineWidth: 3)
                    .frame(width: summaryDiameter, height: summaryDiameter)
                Circle()
                    .trim(from: 0, to: total > 0 ? CGFloat(done) / CGFloat(total) : 0)
                    .stroke(theme.primaryGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: summaryDiameter, height: summaryDiameter)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.6),
                        value: done
                    )
                VStack(spacing: 0) {
                    Text("\(done)")
                        .scaledFont(size: 22, weight: .heavy)
                        .foregroundStyle(theme.ink)
                    Text("/\(total)")
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundStyle(theme.inkMuted)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Achievements")
                    .scaledFont(size: 20, weight: .heavy)
                    .foregroundStyle(theme.ink)
                Text("\(done) of \(total) unlocked")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(theme.inkMuted)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(theme.accent)
                    .frame(maxWidth: 160)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.glassBorder))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Achievements progress")
        .accessibilityValue(Text("\(done) of \(total) unlocked"))
    }

    // MARK: - category section

    private func categorySection(_ category: Achievement.Category) -> some View {
        let items = Achievement.all.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: 12) {
            Text(category.displayName.uppercased())
                .scaledFont(size: 11, weight: .heavy)
                .tracking(1.5)
                .foregroundStyle(theme.inkMuted)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 8) {
                ForEach(items) { achievement in
                    achievementRow(achievement)
                }
            }
        }
    }

    // MARK: - row

    private func achievementRow(_ achievement: Achievement) -> some View {
        let isEarned = earned.contains(achievement.id)
        let accessibilityValue = isEarned
            ? String(localized: "Unlocked. \(achievement.description)")
            : String(localized: "Locked. \(achievement.description)")

        return DynamicTypeStack(spacing: 16) {
            AchievementArtwork(achievement: achievement, isEarned: isEarned)
                .frame(width: 50, height: 50)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isEarned ? theme.accent.opacity(0.45) : theme.glassBorder)
                )
                .shadow(
                    color: isEarned ? theme.accent.opacity(0.18) : .clear,
                    radius: 6,
                    y: 2
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .scaledFont(size: 15, weight: .heavy)
                    .foregroundStyle(isEarned ? theme.ink : theme.inkMuted)
                Text(achievement.description)
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }

            Spacer()

            if isEarned {
                Image(systemName: "checkmark.circle.fill")
                    .scaledFont(size: 20)
                    .foregroundStyle(theme.accent)
            } else {
                Image(systemName: "lock.fill")
                    .scaledFont(size: 16)
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isEarned ? theme.accent.opacity(0.25) : theme.glassBorder)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(achievement.title))
        .accessibilityValue(Text(verbatim: accessibilityValue))
    }
}

// MARK: - Achievement banner overlay

struct AchievementBannerView: View {
    let achievement: Achievement
    let theme: GameTheme
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 44

    var body: some View {
        DynamicTypeStack(spacing: 14) {
            AchievementArtwork(achievement: achievement, isEarned: true)
                .frame(width: iconSize, height: iconSize)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.accent.opacity(0.45))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked!")
                    .scaledFont(size: 11, weight: .heavy)
                    .tracking(1.2)
                    .foregroundStyle(theme.inkMuted)
                Text(achievement.title)
                    .scaledFont(size: 15, weight: .heavy)
                    .foregroundStyle(theme.ink)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .themedGlass(
            theme: theme,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Achievement unlocked: \(achievement.title)"))
    }
}

private struct AchievementArtwork: View {
    let achievement: Achievement
    let isEarned: Bool

    var body: some View {
        Image(achievement.imageAssetName)
            .resizable()
            .scaledToFit()
            .saturation(isEarned ? 1 : 0.15)
            .brightness(isEarned ? 0 : -0.12)
            .opacity(isEarned ? 1 : 0.58)
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack { AchievementsView() }
        .environment(SettingsStore.shared)
        .environment(ProgressStore.shared)
}
