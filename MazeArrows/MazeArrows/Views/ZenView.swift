//
//  ZenView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Endless relax flow: generated levels one after another, no lives pressure,
//  no rewards. Free players get EconomyConfig.zenFreeLevelsPerDay per UTC day;
//  the limit screen is a future premium touchpoint.
//

import SwiftUI

struct ZenView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss

    @State private var level: Level?
    @State private var levelIndex = 0
    @State private var loadError: String?

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }
    private var date: String { DailyPuzzleProvider.todayDateString() }
    private var remaining: Int { progress.zenRemainingToday(date: date) }

    var body: some View {
        if let level {
            GameView(
                model: GameViewModel(
                    level: level,
                    mode: .zen(date: date, index: levelIndex),
                    gameMode: .relax
                ),
                onNext: { self.level = nil }
            )
            .id(level.id)
        } else if remaining <= 0 {
            limitView
        } else if let loadError {
            VStack(spacing: 12) {
                Text("Unable to prepare Zen level")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(loadError)
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    self.loadError = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accent)
            }
            .padding(24)
        } else {
            ProgressView("Preparing Zen level…")
                .tint(theme.accent)
                .foregroundStyle(theme.ink)
                .task(id: remaining) {
                    await loadNextLevel()
                }
        }
    }

    private func loadNextLevel() async {
        guard remaining > 0, level == nil else { return }
        loadError = nil
        let date = self.date
        let index = progress.progress.zenPlayedDate == date ? progress.progress.zenPlayedCount : 0

        do {
            let next = try await ZenProvider.shared.level(date: date, index: index)
            try Task.checkCancellation()
            levelIndex = index
            level = next
        } catch is CancellationError {
            // SwiftUI cancels view-bound tasks when their view disappears.
        } catch {
            loadError = String(localized: "Please try again later.")
        }
    }

    // MARK: - limit screen

    private var limitView: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(theme.surface)
                        .overlay(Circle().stroke(theme.glassBorder))
                        .frame(width: 96, height: 96)
                    Image(systemName: "moon.stars.fill")
                        .scaledFont(size: 40, weight: .bold)
                        .foregroundStyle(theme.accent)
                }
                .accessibilityHidden(true)

                Text("Zen is done for today")
                    .scaledFont(size: 28, weight: .black)
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Come back tomorrow for \(EconomyConfigStore.shared.config.zenFreeLevelsPerDay) more peaceful levels.")
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                VStack(spacing: 10) {
                    if FeatureFlags.premiumOffersEnabled {
                        // Future contextual paywall: unlimited Zen with Premium.
                        GhostButton(text: "Premium — unlimited Zen", theme: theme) {}
                    }
                    PrimaryButton(text: "Back to menu", theme: theme) {
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Analytics.log(.zenLimitHit)
        }
    }
}
