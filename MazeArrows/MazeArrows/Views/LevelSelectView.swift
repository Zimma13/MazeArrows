//
//  LevelSelectView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct LevelSelectView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress
    @Environment(LevelCatalogStore.self) private var levelCatalog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selected: Level?
    @State private var masterLaunch: MasterLaunch?
    @State private var dialogLevel: Level?

    private struct MasterLaunch: Identifiable, Hashable {
        let level: Level
        let modifier: GameMode
        var id: String { "\(level.index)-\(modifier.rawValue)" }
    }

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 160 : 100), spacing: 12)]
    }

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(levelCatalog.levels) { level in
                        levelTile(level)
                    }
                }
                .padding(20)
            }

            if levelCatalog.levels.isEmpty {
                catalogStatus
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Levels")
                    .scaledFont(size: 18, weight: .heavy)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .designedBackButton(theme: theme)
        .edgeFades(theme: theme)
        .navigationDestination(item: $selected) { level in
            GameView(
                model: GameViewModel(
                    level: level,
                    mode: .story(index: level.index),
                    gameMode: .classic
                )
            ) {
                let next = level.index + 1
                if let nextLevel = levelCatalog.level(at: next) {
                    selected = nextLevel
                } else {
                    selected = nil
                }
            }
            .id(level.index)
        }
        .navigationDestination(item: $masterLaunch) { launch in
            GameView(
                model: GameViewModel(
                    level: launch.level,
                    mode: .master(index: launch.level.index),
                    gameMode: launch.modifier
                )
            )
            .id(launch.id)
        }
        .confirmationDialog(
            Text("Level \(dialogLevel?.index ?? 0)"),
            isPresented: Binding(
                get: { dialogLevel != nil },
                set: { if !$0 { dialogLevel = nil } }
            ),
            titleVisibility: .visible,
            presenting: dialogLevel
        ) { level in
            Button(String(localized: "Replay")) {
                selected = level
            }
            ForEach(GameMode.masterModifiers, id: \.self) { modifier in
                Button(masterChoiceLabel(modifier: modifier, level: level)) {
                    masterLaunch = MasterLaunch(level: level, modifier: modifier)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: { _ in
            Text("Master runs pay \(EconomyConfigStore.shared.config.masterClearReward) coins once per mode.")
        }
        .task {
            await levelCatalog.loadIfNeeded()
        }
    }

    private func masterChoiceLabel(modifier: GameMode, level: Level) -> String {
        let cleared = progress.masterClears(levelIndex: level.index).contains(modifier)
        return cleared
            ? String(localized: "\(modifier.displayName) ✓")
            : modifier.displayName
    }

    @ViewBuilder
    private var catalogStatus: some View {
        if levelCatalog.isLoading || levelCatalog.loadErrorDescription == nil {
            ProgressView("Loading levels…")
                .tint(theme.accent)
                .foregroundStyle(theme.ink)
        } else {
            VStack(spacing: 12) {
                Text("Unable to load levels")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Button("Retry") {
                    Task { await levelCatalog.loadIfNeeded() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accent)
            }
        }
    }

    private func levelTile(_ level: Level) -> some View {
        let unlocked = progress.progress.isUnlocked(level.index)
        let completed = progress.progress.completedLevels.contains(level.index)
        let stars = progress.progress.bestStars(level.index)
        let bestTime = progress.progress.bestTime(level.index)
        let isPerfect = stars >= 3
        let crowns = progress.masterClears(levelIndex: level.index).count

        return Button {
            guard unlocked else { return }
            if completed {
                dialogLevel = level
            } else {
                selected = level
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(level.index)")
                    .scaledFont(size: 30, weight: .heavy)
                    .foregroundStyle(unlocked ? theme.ink : theme.inkMuted)
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .scaledFont(size: 11, weight: .black)
                            .foregroundStyle(i < stars ? theme.accent2 : theme.inkMuted)
                    }
                }
                if let bestTime, unlocked {
                    Text(formatTime(bestTime))
                        .scaledFont(size: 11, weight: .heavy, design: .rounded)
                        .foregroundStyle(theme.inkSoft)
                        .monospacedDigit()
                } else {
                    Text(level.difficulty.displayName)
                        .scaledFont(size: 11, weight: .heavy)
                        .tracking(0.8)
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(borderColor(isPerfect: isPerfect, unlocked: unlocked),
                                    lineWidth: isPerfect ? 2 : 1)
                    )
                    .shadow(
                        color: isPerfect ? theme.rewardGold.opacity(0.30) : .clear,
                        radius: isPerfect ? 8 : 0
                    )
            )
            .overlay {
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundStyle(theme.inkMuted)
                        .offset(y: 28)
                }
            }
            .overlay(alignment: .topTrailing) {
                if crowns > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "crown.fill")
                            .scaledFont(size: 9, weight: .black)
                        Text("\(crowns)")
                            .scaledFont(size: 10, weight: .heavy)
                    }
                    .foregroundStyle(theme.textOnRewardGold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(theme.rewardGold))
                    .offset(x: 4, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(Text("Level \(level.index)"))
        .accessibilityValue(Text(levelAccessibilityValue(
            level: level,
            unlocked: unlocked,
            stars: stars,
            bestTime: bestTime,
            crowns: crowns
        )))
        .accessibilityHint(Text(accessibilityHint(unlocked: unlocked, completed: completed)))
    }

    private func accessibilityHint(unlocked: Bool, completed: Bool) -> String {
        guard unlocked else {
            return String(localized: "Complete earlier levels to unlock.")
        }
        return completed
            ? String(localized: "Opens replay and master challenge options.")
            : String(localized: "Opens this level.")
    }

    private func levelAccessibilityValue(
        level: Level,
        unlocked: Bool,
        stars: Int,
        bestTime: Int?,
        crowns: Int
    ) -> String {
        guard unlocked else {
            return String(localized: "Locked. \(level.difficulty.displayName) difficulty.")
        }
        var value = String(localized: "Unlocked. \(stars) of 3 stars. \(level.difficulty.displayName) difficulty.")
        if let bestTime {
            value += " " + String(localized: "Best time \(formatTime(bestTime)).")
        }
        if crowns > 0 {
            value += " " + String(localized: "\(crowns) of 3 master crowns.")
        }
        return value
    }

    private func borderColor(isPerfect: Bool, unlocked: Bool) -> Color {
        if !unlocked { return theme.glassBorder }
        if isPerfect { return theme.rewardGold }
        return theme.glassBorder
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    NavigationStack { LevelSelectView() }
        .environment(SettingsStore.shared)
        .environment(ProgressStore.shared)
        .environment(LevelCatalogStore.shared)
}
