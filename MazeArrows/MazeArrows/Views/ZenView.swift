//
//  ZenView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Endless relax flow: generated levels one after another, no lives pressure,
//  no rewards. Date and position identify each board.
//

import SwiftUI

struct ZenView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress

    @State private var model: GameViewModel?
    @State private var loadError: String?

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }

    var body: some View {
        if let model {
            GameView(model: model, onNext: { self.model = nil })
                .id(model.level.id)
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
                .task {
                    await loadNextLevel()
                }
        }
    }

    private func loadNextLevel() async {
        guard model == nil else { return }
        loadError = nil
        let date = DailyPuzzleProvider.todayDateString()
        let index = progress.nextZenIndex(date: date)

        do {
            let next = try await ZenProvider.shared.level(date: date, index: index)
            try Task.checkCancellation()
            model = GameViewModel(
                level: next,
                mode: .zen(date: date, index: index),
                gameMode: .relax,
                progressStore: progress
            )
        } catch is CancellationError {
            // SwiftUI cancels view-bound tasks when their view disappears.
        } catch {
            loadError = String(localized: "Please try again later.")
        }
    }
}
