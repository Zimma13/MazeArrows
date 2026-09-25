//
//  WorldMapView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  World Maze Journey — scrollable chapter map.
//

import SwiftUI

struct WorldMapView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progressStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedChapter: Chapter?
    @State private var showWeekly = false
    @State private var showWeeklyGame = false
    @State private var weeklyPuzzle: Level?
    @State private var weeklyPuzzleKey: String?
    @State private var weeklyLoadError: String?
    @State private var weeklyStartRequestID: UUID?

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }
    private var progress: PlayerProgress { progressStore.progress }

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.bottom, 32)

                    ForEach(Array(Chapter.all.enumerated()), id: \.element.id) { index, chapter in
                        chapterNode(chapter: chapter, isLast: index == Chapter.all.count - 1)
                    }

                    weeklyNode
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
            }
        }
        .navigationDestination(item: $selectedChapter) { chapter in
            ChapterLevelSelectView(chapter: chapter)
        }
        .navigationDestination(isPresented: $showWeeklyGame) {
            weeklyDestination
        }
        .sheet(isPresented: $showWeekly) {
            WeeklyChallengeSheet(theme: theme, onStart: {
                showWeekly = false
                weeklyStartRequestID = UUID()
            })
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("World Journey")
                    .scaledFont(size: 18, weight: .heavy)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .designedBackButton(theme: theme)
        .edgeFades(theme: theme)
        .task(id: WeeklyChallengeProvider.currentWeekString()) {
            await loadWeeklyPuzzle()
        }
        .task(id: weeklyStartRequestID) {
            guard let requestID = weeklyStartRequestID else { return }
            if reduceMotion {
                await Task.yield()
            } else {
                do {
                    try await Task.sleep(for: .milliseconds(350))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled, weeklyStartRequestID == requestID else { return }
            showWeeklyGame = true
            weeklyStartRequestID = nil
        }
    }

    // MARK: - header

    private var header: some View {
        VStack(spacing: 6) {
            let total = Chapter.all.reduce(0) { $0 + $1.completedCount(in: progress.completedLevels) }
            let maxLevels = Chapter.all.reduce(0) { $0 + $1.levelCount }
            let totalStars = Chapter.all.reduce(0) { $0 + $1.totalStars(from: progress.stars) }
            let maxStars = Chapter.all.reduce(0) { $0 + $1.maxStars() }

            DynamicTypeStack(spacing: 12) {
                statPill(label: "Levels", value: "\(total)/\(maxLevels)", icon: "flag.fill")
                statPill(label: "Stars", value: "\(totalStars)/\(maxStars)", icon: "star.fill")
                statPill(label: "Coins", value: "\(progress.coins)", icon: "circle.fill")
            }
        }
    }

    private func statPill(label: LocalizedStringKey, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .scaledFont(size: 16, weight: .bold)
                .foregroundStyle(theme.accent)
            Text(value)
                .scaledFont(size: 15, weight: .heavy)
                .foregroundStyle(theme.ink)
            Text(label)
                .textCase(.uppercase)
                .scaledFont(size: 11, weight: .heavy)
                .tracking(1)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.glassBorder))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }

    // MARK: - chapter node

    private func chapterNode(chapter: Chapter, isLast: Bool) -> some View {
        let unlocked = chapter.isUnlocked(progress: progress)
        let complete = chapter.isComplete(progress: progress)
        let done = chapter.completedCount(in: progress.completedLevels)
        let earned = chapter.totalStars(from: progress.stars)
        let maxS = chapter.maxStars()

        return VStack(spacing: 0) {
            Button {
                if unlocked { selectedChapter = chapter }
            } label: {
                DynamicTypeStack(spacing: 18) {
                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(unlocked ? theme.primaryGradient : LinearGradient(colors: [theme.surface, theme.surface], startPoint: .top, endPoint: .bottom))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Circle().stroke(complete ? theme.achievementGold : theme.glassBorder, lineWidth: complete ? 2.5 : 1)
                            )
                            .shadow(
                                color: unlocked ? theme.primaryShadow.opacity(0.35) : .clear,
                                radius: 10, x: 0, y: 5
                            )

                        if unlocked {
                            Image(systemName: chapter.icon)
                                .scaledFont(size: 26, weight: .bold)
                                .foregroundStyle(theme.primaryText)
                        } else {
                            Image(systemName: "lock.fill")
                                .scaledFont(size: 22, weight: .bold)
                                .foregroundStyle(theme.inkMuted)
                        }

                        if complete {
                            Image(systemName: "checkmark.circle.fill")
                                .scaledFont(size: 20, weight: .bold)
                                .foregroundStyle(theme.achievementGold)
                                .offset(x: 22, y: -22)
                        }
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chapter.title)
                            .scaledFont(size: 20, weight: .heavy)
                            .foregroundStyle(unlocked ? theme.ink : theme.inkMuted)
                        Text(chapter.subtitle)
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundStyle(theme.inkMuted)

                        if unlocked {
                            HStack(spacing: 6) {
                                ProgressView(value: Double(done), total: Double(chapter.levelCount))
                                    .tint(theme.accent)
                                    .frame(width: 80)
                                Text("\(done)/\(chapter.levelCount)")
                                    .scaledFont(size: 11, weight: .bold)
                                    .foregroundStyle(theme.inkSoft)
                                Spacer()
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .scaledFont(size: 11, weight: .black)
                                        .foregroundStyle(theme.achievementGold)
                                    Text("\(earned)/\(maxS)")
                                        .scaledFont(size: 11, weight: .bold)
                                        .foregroundStyle(theme.inkSoft)
                                }
                            }
                        }
                    }

                    Spacer()

                    if unlocked {
                        Image(systemName: "chevron.right")
                            .scaledFont(size: 13, weight: .bold)
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(complete ? theme.achievementGold : theme.glassBorder,
                                        lineWidth: complete ? 2 : 1)
                        )
                        .shadow(
                            color: complete ? theme.achievementGold.opacity(0.20) : .clear,
                            radius: 12
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!unlocked)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(chapter.title))
            .accessibilityValue(Text(verbatim: chapterAccessibilityValue(
                chapter: chapter,
                unlocked: unlocked,
                complete: complete,
                levelsDone: done,
                starsEarned: earned,
                maximumStars: maxS
            )))
            .accessibilityHint(Text(chapterAccessibilityHint(unlocked: unlocked)))

            // Connector path between chapters
            if !isLast {
                let nextLocked = Chapter.all.first(where: { $0.id == chapter.id + 1 })
                    .map { !$0.isUnlocked(progress: progress) } ?? false
                connector(locked: nextLocked)
            }
        }
    }

    private func chapterAccessibilityValue(
        chapter: Chapter,
        unlocked: Bool,
        complete: Bool,
        levelsDone: Int,
        starsEarned: Int,
        maximumStars: Int
    ) -> String {
        guard unlocked else {
            return String(localized: "Locked. \(chapter.subtitle)")
        }
        let state = complete
            ? String(localized: "Completed")
            : String(localized: "Unlocked")
        return String(
            localized: "\(state). \(levelsDone) of \(chapter.levelCount) levels. \(starsEarned) of \(maximumStars) stars. \(chapter.subtitle)"
        )
    }

    private func chapterAccessibilityHint(unlocked: Bool) -> LocalizedStringKey {
        unlocked ? "Opens this chapter." : "Complete the previous chapter to unlock."
    }

    private func weeklySubtitleKey(done: Bool) -> LocalizedStringKey {
        done ? "Completed!" : "Hard · Bonus 150 coins"
    }

    private func connector(locked: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(locked ? theme.glassBorder : theme.accent.opacity(0.4))
                    .frame(width: 4, height: 8)
                    .offset(x: i % 2 == 0 ? -6 : 6)
                Spacer().frame(height: 4)
            }
        }
        .frame(height: 60)
        .accessibilityHidden(true)
    }

    // MARK: - weekly node

    private var weeklyNode: some View {
        let week = WeeklyChallengeProvider.currentWeekString()
        let done = progressStore.progress.hasCompletedWeekly(week)

        return Button {
            showWeekly = true
        } label: {
            DynamicTypeStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: done
                                ? [theme.achievementGold, theme.achievementGold]
                                : [theme.accent2, theme.accent2.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 64, height: 64)
                        .shadow(color: theme.accent2.opacity(0.4), radius: 10, x: 0, y: 5)

                    Image(systemName: done ? "trophy.fill" : "calendar.badge.clock")
                        .scaledFont(size: 26, weight: .bold)
                        .foregroundStyle(done ? .white : theme.textOnAccent2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Challenge")
                        .scaledFont(size: 20, weight: .heavy)
                        .foregroundStyle(theme.ink)
                    Text(week)
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundStyle(theme.inkMuted)
                    Text(weeklySubtitleKey(done: done))
                        .scaledFont(size: 12, weight: .bold)
                        .foregroundStyle(theme.inkSoft)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .scaledFont(size: 13, weight: .bold)
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(done ? theme.achievementGold : theme.glassBorder,
                                    lineWidth: done ? 2 : 1)
                    )
                    .shadow(
                        color: done ? theme.achievementGold.opacity(0.20) : .clear,
                        radius: 12
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly challenge")
        .accessibilityValue(Text(verbatim: done
            ? String(localized: "Completed. \(week)")
            : String(localized: "\(week). Hard difficulty. Bonus 150 coins.")))
        .accessibilityHint("Opens challenge details.")
    }

    @ViewBuilder
    private var weeklyDestination: some View {
        if let level = weeklyPuzzle, let week = weeklyPuzzleKey {
            GameView(
                model: GameViewModel(
                    level: level,
                    mode: .weekly(week: week),
                    gameMode: .classic
                )
            ) {
                showWeeklyGame = false
            }
            .id(week)
        } else if let weeklyLoadError {
            VStack(spacing: 12) {
                Text("Unable to prepare weekly challenge")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(weeklyLoadError)
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    self.weeklyLoadError = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accent)
            }
            .padding(24)
        } else {
            ProgressView("Preparing weekly challenge…")
                .tint(theme.accent)
                .foregroundStyle(theme.ink)
                .task {
                    await loadWeeklyPuzzle()
                }
        }
    }

    private func loadWeeklyPuzzle() async {
        let week = WeeklyChallengeProvider.currentWeekString()
        guard weeklyPuzzleKey != week || weeklyPuzzle == nil else { return }
        weeklyLoadError = nil

        do {
            let level = try await WeeklyChallengeProvider.shared.puzzle(for: week)
            try Task.checkCancellation()
            guard WeeklyChallengeProvider.currentWeekString() == week else { return }
            weeklyPuzzleKey = week
            weeklyPuzzle = level
        } catch is CancellationError {
            // SwiftUI cancels view-bound tasks when their view disappears.
        } catch {
            weeklyLoadError = String(localized: "Please try again later.")
        }
    }
}

// MARK: - Chapter level select

struct ChapterLevelSelectView: View {
    let chapter: Chapter
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progressStore
    @Environment(LevelCatalogStore.self) private var levelCatalog
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected: Level?

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 160 : 100), spacing: 12)]
    }
    private var levels: [Level] {
        levelCatalog.levels.filter { chapter.levelRange.contains($0.index) }
    }

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    chapterHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(levels) { level in
                            levelTile(level)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }

            if levels.isEmpty {
                catalogStatus
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(chapter.title)
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
                if let nextLevel = levelCatalog.level(at: next),
                   chapter.levelRange.contains(next) {
                    selected = nextLevel
                } else {
                    selected = nil
                }
            }
            .id(level.index)
        }
        .task {
            await levelCatalog.loadIfNeeded()
        }
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

    private var chapterHeader: some View {
        let done = chapter.completedCount(in: progressStore.progress.completedLevels)
        let earned = chapter.totalStars(from: progressStore.progress.stars)

        return DynamicTypeStack(spacing: 14) {
            Image(systemName: chapter.icon)
                .scaledFont(size: 22, weight: .bold)
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.subtitle)
                    .scaledFont(size: 13, weight: .heavy)
                    .tracking(0.5)
                    .foregroundStyle(theme.inkMuted)
                Text("\(done)/\(chapter.levelCount) levels · \(earned)/\(chapter.maxStars()) stars")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundStyle(theme.inkSoft)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(chapter.title))
        .accessibilityValue(Text("\(done) of \(chapter.levelCount) levels. \(earned) of \(chapter.maxStars()) stars."))
        .accessibilityAddTraits(.isHeader)
    }

    private func levelTile(_ level: Level) -> some View {
        let progress = progressStore.progress
        let unlocked = progress.isUnlocked(level.index)
        let stars = progress.bestStars(level.index)
        let bestTime = progress.bestTime(level.index)
        let isPerfect = stars >= 3

        return Button {
            if unlocked { selected = level }
        } label: {
            VStack(spacing: 4) {
                Text("\(level.index)")
                    .scaledFont(size: 30, weight: .heavy)
                    .foregroundStyle(unlocked ? theme.ink : theme.inkMuted)
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .scaledFont(size: 11, weight: .black)
                            .foregroundStyle(i < stars ? theme.achievementGold : theme.inkMuted)
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
                            .stroke(isPerfect ? theme.achievementGold : theme.glassBorder,
                                    lineWidth: isPerfect ? 2 : 1)
                    )
                    .shadow(
                        color: isPerfect ? theme.achievementGold.opacity(0.30) : .clear,
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
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(Text("Level \(level.index)"))
        .accessibilityValue(Text(levelAccessibilityValue(
            level: level,
            unlocked: unlocked,
            stars: stars,
            bestTime: bestTime
        )))
        .accessibilityHint(Text(levelAccessibilityHint(unlocked: unlocked)))
    }

    private func levelAccessibilityValue(
        level: Level,
        unlocked: Bool,
        stars: Int,
        bestTime: Int?
    ) -> String {
        guard unlocked else {
            return String(localized: "Locked. \(level.difficulty.displayName) difficulty.")
        }
        var value = String(localized: "Unlocked. \(stars) of 3 stars. \(level.difficulty.displayName) difficulty.")
        if let bestTime {
            value += " " + String(localized: "Best time \(formatTime(bestTime)).")
        }
        return value
    }

    private func levelAccessibilityHint(unlocked: Bool) -> LocalizedStringKey {
        unlocked ? "Opens this level." : "Complete earlier levels to unlock."
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Weekly Challenge Sheet

struct WeeklyChallengeSheet: View {
    @Environment(ProgressStore.self) private var progressStore
    let theme: GameTheme
    let onStart: () -> Void

    private var week: String { WeeklyChallengeProvider.currentWeekString() }
    private var isDone: Bool { progressStore.progress.hasCompletedWeekly(week) }

    var body: some View {
        ZStack {
            theme.appBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                Image(systemName: isDone ? "trophy.fill" : "calendar.badge.clock")
                    .scaledFont(size: 52, weight: .bold)
                    .foregroundStyle(isDone
                        ? LinearGradient(colors: [theme.achievementGold,
                                                   theme.achievementGold],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [theme.accent2, theme.accent2],
                                         startPoint: .top, endPoint: .bottom))

                VStack(spacing: 8) {
                    Text("Weekly Challenge")
                        .scaledFont(size: 28, weight: .heavy)
                        .foregroundStyle(theme.ink)
                    Text(week)
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(theme.inkMuted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 10) {
                        infoRow(icon: "bolt.fill",   label: "Difficulty",  value: "Hard")
                        infoRow(icon: "circle.fill",  label: "Reward",      value: "150 coins")
                        infoRow(icon: "trophy.fill",  label: "Achievement", value: "Weekly Champion")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(theme.glassBorder))
                    )
                    .padding(.horizontal, 24)

                    if isDone {
                        Text("You've conquered this week's challenge!")
                            .scaledFont(size: 15, weight: .semibold)
                            .foregroundStyle(theme.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        PrimaryButton(text: "Start Challenge", theme: theme, action: onStart)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 16)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func infoRow(icon: String, label: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        DynamicTypeStack(spacing: 8) {
            Image(systemName: icon)
                .scaledFont(size: 14, weight: .bold)
                .foregroundStyle(theme.accent)
                .frame(width: 24)
            Text(label)
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(theme.inkMuted)
            Spacer()
            Text(value)
                .scaledFont(size: 14, weight: .heavy)
                .foregroundStyle(theme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}

#Preview {
    NavigationStack { WorldMapView() }
        .environment(SettingsStore.shared)
        .environment(ProgressStore.shared)
        .environment(LevelCatalogStore.shared)
}
