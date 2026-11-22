//
//  MainMenuView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct MainMenuView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(ProgressStore.self) private var progress
    @Environment(LevelCatalogStore.self) private var levelCatalog
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var path: [Route] = []
    @State private var showDailyQuests = false
    @State private var dailyPuzzle: Level?
    @State private var dailyPuzzleDate: String?
    @State private var dailyLoadError: String?
    @State private var menuBackgroundLevel: Level?
    @State private var isStartingStory = false

    init(initialRoute: Route? = nil) {
        _path = State(initialValue: initialRoute.map { [$0] } ?? [])
    }

    enum Route: Hashable {
        case story(Int)
        case daily
        case zen
        case levelSelect
        case worldMap
        case achievements
        case settings
        case photoMaze
    }

    private var theme: GameTheme { GameTheme.theme(for: settings.settings.themeID) }

    /// Dense enough to read as a difficult maze, but still bounded to forty
    /// lightweight arrow nodes in the menu-only scene.
    private var preferredMenuBackgroundLevel: Level? {
        levelCatalog.level(at: 68)
            ?? levelCatalog.levels.first(where: {
                $0.pieces.count >= 30 && $0.obstacles.isEmpty
            })
    }

    private var menuLegibilityScrim: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.appBackgroundTop.opacity(colorSchemeContrast == .increased ? 0.86 : 0.55),
                    theme.appBackgroundTop.opacity(colorSchemeContrast == .increased ? 0.42 : 0.12),
                    theme.appBackgroundTop.opacity(colorSchemeContrast == .increased ? 0.68 : 0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    theme.appBackgroundTop.opacity(colorSchemeContrast == .increased ? 0.68 : 0.34),
                    .clear
                ],
                center: .top,
                startRadius: 36,
                endRadius: 350
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                // Remove the renderer completely while another screen is open.
                // A paused, blurred SKView would still take part in the first
                // navigation frames and can contend with the gameplay scene.
                if path.isEmpty,
                   !showDailyQuests,
                   !isStartingStory,
                   !reduceTransparency,
                   let level = menuBackgroundLevel {
                    MenuMazeBackgroundView(
                        level: level,
                        theme: theme,
                        blurRadius: 3,
                        opacityScale: 1.2,
                        onReady: PerformanceTrace.menuBackgroundReady
                    )
                    .id("\(level.id)-\(theme.id.rawValue)")
                    .ignoresSafeArea()
                }

                menuLegibilityScrim

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            Spacer(minLength: 12)
                            titleBlock
                            Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 22 : 44)
                            buttonsStack
                            Spacer().frame(height: 12)
                        }
                        .frame(maxWidth: 680)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 36)
                    }
                }
                .accessibilityHidden(!path.isEmpty || showDailyQuests)
                .overlay(alignment: .topTrailing) {
                    CoinBalanceChip(coins: progress.progress.coins, theme: theme)
                        .padding(.trailing, 20)
                        .padding(.top, 8)
                        .accessibilityHidden(!path.isEmpty || showDailyQuests)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .story(let index):
                    storyDestination(index: index)
                case .daily:
                    dailyDestination
                case .zen:
                    ZenView()
                case .levelSelect:
                    LevelSelectView()
                case .worldMap:
                    WorldMapView()
                case .achievements:
                    AchievementsView()
                case .settings:
                    SettingsView()
                case .photoMaze:
                    PhotoLevelView()
                }
            }
            .sheet(isPresented: $showDailyQuests) {
                DailyQuestsView()
                    .environment(settings)
                    .environment(progress)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            progress.refreshDailyQuestsIfNeeded()
            PerformanceTrace.menuReady()
        }
        .task(id: reduceTransparency) {
            if reduceTransparency {
                menuBackgroundLevel = nil
            } else {
                await prepareMenuBackground()
            }
        }
    }

    private func prepareMenuBackground() async {
        PerformanceTrace.beginMenuBackgroundLoad()
        if preferredMenuBackgroundLevel == nil {
            await levelCatalog.loadIfNeeded()
        }

        guard !Task.isCancelled,
              let level = preferredMenuBackgroundLevel,
              menuBackgroundLevel?.id != level.id
        else { return }

        menuBackgroundLevel = level
    }

    private func startStory() {
        guard !isStartingStory else { return }
        let target = clampedStartIndex
        let mode = GameViewModel.LevelMode.story(index: target)

        isStartingStory = true
        Analytics.log(.playTapped(levelIndex: target))
        PerformanceTrace.beginLevelLoad(
            contentID: mode.analyticsContentIdentifier,
            mode: mode.analyticsModeIdentifier
        )

        // Give SwiftUI one update cycle to detach the blurred menu SKView
        // before SpriteKit prepares the interactive game scene. This prevents
        // both renderers from doing their heaviest first-frame work together.
        Task { @MainActor in
            await Task.yield()
            path.append(.story(target))
            isStartingStory = false
        }
    }

    // MARK: - layout

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text(verbatim: "Arrow")
                .scaledFont(size: 60, weight: .black, design: .rounded)
                .foregroundStyle(theme.ink)
                .tracking(-1.5)
            Text(verbatim: "Maze")
                .scaledFont(size: 60, weight: .black, design: .rounded)
                .foregroundStyle(theme.accent)
                .tracking(-1.5)
            Text("Untangle every path")
                .textCase(.uppercase)
                .scaledFont(size: 13, weight: .semibold)
                .tracking(2)
                .foregroundStyle(theme.inkMuted)
                .padding(.top, 6)
        }
        .artworkLegibility(theme: theme)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Arrow Maze. Untangle every path.")
        .accessibilityAddTraits(.isHeader)
    }

    private var buttonsStack: some View {
        VStack(spacing: 12) {
            PrimaryButton(text: "Play", theme: theme, action: startStory)
                .disabled(isStartingStory)

            AdaptiveGlassEffectContainer(spacing: 8) {
                secondaryButtons
            }
        }
    }

    private var secondaryButtons: some View {
        VStack(spacing: 12) {
            DynamicTypeStack(spacing: 10) {
                GhostButton(text: "Journey", theme: theme, prominence: .interactiveGlass) {
                    path.append(.worldMap)
                }
                GhostButton(text: "Levels", theme: theme, prominence: .interactiveGlass) {
                    path.append(.levelSelect)
                }
            }

            DynamicTypeStack(spacing: 10) {
                GhostButton(text: "Daily", theme: theme, prominence: .interactiveGlass) {
                    path.append(.daily)
                }
                dailyQuestsButton
            }

            DynamicTypeStack(spacing: 10) {
                GhostButton(text: "Zen", theme: theme, prominence: .interactiveGlass) {
                    path.append(.zen)
                }
                GhostButton(text: "Photo Maze", theme: theme, prominence: .interactiveGlass) {
                    path.append(.photoMaze)
                }
            }

            HStack(spacing: 12) {
                CircleMenuButton(systemImage: "trophy.fill", accessibilityLabel: "Achievements", theme: theme) {
                    path.append(.achievements)
                }
                CircleMenuButton(systemImage: "gearshape.fill", accessibilityLabel: "Settings", theme: theme) {
                    path.append(.settings)
                }
            }
            .padding(.top, 4)
        }
    }

    private var dailyQuestsButton: some View {
        let quests = progress.currentQuests
        let done = quests.filter { $0.isComplete }.count
        let total = quests.count
        let hasUnclaimed = quests.contains { q in
            q.isComplete && !progress.progress.dailyQuestState.claimedRewards.contains(q.id)
        }

        return Button {
            showDailyQuests = true
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    Text("Quests")
                        .textCase(.uppercase)
                        .scaledFont(size: 14, weight: .bold)
                        .foregroundStyle(theme.ink)
                    if hasUnclaimed {
                        Image(systemName: "gift.fill")
                            .scaledFont(size: 11, weight: .black)
                            .foregroundStyle(theme.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

                if total > 0 {
                    Text("\(done)/\(total)")
                        .scaledFont(size: 11, weight: .heavy)
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(theme.primaryGradient)
                        )
                        .offset(x: 6, y: -8)
                        .zIndex(1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            // Keep the badge in the button's content layer. Native Liquid
            // Glass is then composited behind it instead of above it.
            .artworkLegibility(theme: theme)
            .themedGlass(
                theme: theme,
                in: Capsule(),
                prominence: .interactiveGlass,
                emphasizedBorder: hasUnclaimed
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Daily quests")
        .accessibilityValue(Text(verbatim: hasUnclaimed
            ? String(localized: "\(done) of \(total) completed. Reward available.")
            : String(localized: "\(done) of \(total) completed.")))
        .zIndex(total > 0 ? 1 : 0)
    }

    // MARK: - destinations

    private var clampedStartIndex: Int {
        let max = levelCatalog.maxHandcraftedIndex
        return min(max, max == 0 ? 1 : progress.progress.unlockedLevelIndex)
    }

    private func storyDestination(index: Int) -> some View {
        StoryDestinationView(index: index) {
            let nextIndex = index + 1
            let newRoute: Route? = levelCatalog.level(at: nextIndex) != nil
                ? .story(nextIndex)
                : nil
            Task { @MainActor in
                if let newRoute {
                    var newPath = path
                    if !newPath.isEmpty { newPath.removeLast() }
                    newPath.append(newRoute)
                    path = newPath
                } else {
                    path.removeAll()
                }
            }
        } onBack: {
            if !path.isEmpty { path.removeLast() }
        }
    }

    @ViewBuilder
    private var dailyDestination: some View {
        if let level = dailyPuzzle, let date = dailyPuzzleDate {
            GameView(model: GameViewModel(
                level: level,
                mode: .daily(date: date),
                gameMode: .zenDaily
            ))
            .id(date)
        } else if let dailyLoadError {
            VStack(spacing: 12) {
                Text("Unable to prepare daily puzzle")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(dailyLoadError)
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    self.dailyLoadError = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accent)
            }
            .padding(24)
        } else {
            ProgressView("Preparing daily puzzle…")
                .tint(theme.accent)
                .foregroundStyle(theme.ink)
                .task {
                    await loadDailyPuzzle()
                }
        }
    }

    private func loadDailyPuzzle() async {
        let date = DailyPuzzleProvider.todayDateString()
        guard dailyPuzzleDate != date || dailyPuzzle == nil else { return }
        dailyLoadError = nil

        do {
            let level = try await DailyPuzzleProvider.shared.puzzle(for: date)
            try Task.checkCancellation()
            guard DailyPuzzleProvider.todayDateString() == date else { return }
            dailyPuzzleDate = date
            dailyPuzzle = level
        } catch is CancellationError {
            // SwiftUI cancels view-bound tasks when their view disappears.
        } catch {
            dailyLoadError = String(localized: "Please try again later.")
        }
    }
}

/// A navigation destination must own the catalog reads in its `body`.
/// `NavigationStack` may cache the value returned by its destination builder,
/// so evaluating the loading condition in `MainMenuView` can leave that cached
/// value stuck as a `ProgressView` until the route is pushed a second time.
private struct StoryDestinationView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(LevelCatalogStore.self) private var levelCatalog

    let index: Int
    let onNext: () -> Void
    let onBack: () -> Void

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }

    var body: some View {
        Group {
            if let level = levelCatalog.level(at: index) {
                GameView(
                    model: GameViewModel(
                        level: level,
                        mode: .story(index: index),
                        gameMode: .classic
                    ),
                    onNext: onNext
                )
                .id(index)
            } else if levelCatalog.isLoading || levelCatalog.loadErrorDescription == nil {
                ProgressView("Loading levels…")
                    .task {
                        await levelCatalog.loadIfNeeded()
                    }
            } else {
                VStack {
                    Text("Level \(index) not available")
                        .foregroundStyle(theme.ink)
                    Button {
                        Task { await levelCatalog.loadIfNeeded() }
                    } label: {
                        Text("Retry").minimumTapTarget()
                    }
                    Button(action: onBack) {
                        Text("Back").minimumTapTarget()
                    }
                }
            }
        }
    }
}

// MARK: - Circle menu button

private struct CircleMenuButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let theme: GameTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .scaledFont(size: 18, weight: .semibold)
                .foregroundStyle(theme.inkSoft)
                .frame(width: 48, height: 48)
                .artworkLegibility(theme: theme)
                .themedGlass(theme: theme, in: Circle(), prominence: .interactiveGlass)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

#Preview {
    MainMenuView()
        .environment(SettingsStore.shared)
        .environment(ProgressStore.shared)
        .environment(LevelCatalogStore.shared)
}
