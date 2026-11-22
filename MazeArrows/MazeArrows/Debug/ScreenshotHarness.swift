#if DEBUG
import Foundation
import SwiftUI

/// Deterministic, non-shipping entry points used to capture the real app UI
/// for App Store artwork. Launch with:
/// `--screenshot-scene photo|mechanic|combo|worlds|daily|quests`.
enum ScreenshotCaptureScene: String, CaseIterable, Sendable {
    case photo
    case mechanic
    case combo
    case worlds
    case daily
    case quests

    var usesGameScene: Bool {
        switch self {
        case .photo, .mechanic, .combo, .daily:
            true
        case .worlds, .quests:
            false
        }
    }
}

struct ScreenshotCaptureConfiguration: Sendable {
    let scene: ScreenshotCaptureScene
    let hidesStatusBar: Bool

    static let current: ScreenshotCaptureConfiguration? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "--screenshot-scene"),
              arguments.indices.contains(flagIndex + 1),
              let scene = ScreenshotCaptureScene(rawValue: arguments[flagIndex + 1])
        else { return nil }

        return ScreenshotCaptureConfiguration(
            scene: scene,
            hidesStatusBar: arguments.contains("--screenshot-hide-status-bar")
        )
    }()
}

/// A small file marker lets the capture script wait for SwiftUI/SpriteKit
/// instead of relying on a fragile fixed delay. The script should still wait
/// one short render interval after the marker before invoking `simctl io`.
@MainActor
enum ScreenshotCaptureSignal {
    private static var didBegin = false
    private static var didMarkReady = false

    static func begin(_ configuration: ScreenshotCaptureConfiguration) {
        guard !didBegin else { return }
        didBegin = true
        didMarkReady = false
        try? FileManager.default.removeItem(at: markerURL(for: configuration.scene))
    }

    static func markReady() {
        guard !didMarkReady,
              let configuration = ScreenshotCaptureConfiguration.current
        else { return }

        didMarkReady = true
        let marker = markerURL(for: configuration.scene)
        try? FileManager.default.createDirectory(
            at: marker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? Data("ready\n".utf8).write(to: marker, options: .atomic)
    }

    static func markerURL(for scene: ScreenshotCaptureScene) -> URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        return documents
            .appendingPathComponent("ScreenshotCapture", isDirectory: true)
            .appendingPathComponent("\(scene.rawValue).ready")
    }
}

struct ScreenshotHarnessView: View {
    @Environment(LevelCatalogStore.self) private var levelCatalog

    let configuration: ScreenshotCaptureConfiguration
    @State private var captureProgress: ProgressStore

    init(configuration: ScreenshotCaptureConfiguration) {
        self.configuration = configuration

        let defaults = UserDefaults(
            suiteName: "zimma.MazeArrows.ScreenshotCapture.\(configuration.scene.rawValue)"
        ) ?? .standard
        let store = ProgressStore(defaults: defaults)
        store.progress = Self.progressFixture(for: configuration.scene)
        _captureProgress = State(initialValue: store)

        ScreenshotCaptureSignal.begin(configuration)
    }

    var body: some View {
        sceneContent
            .environment(captureProgress)
            .statusBarHidden(configuration.hidesStatusBar)
    }

    @ViewBuilder
    private var sceneContent: some View {
        switch configuration.scene {
        case .photo:
            NavigationStack {
                ScreenshotGameView(
                    level: ScreenshotParrotFixture.makeLevel(),
                    mode: .generated(difficulty: .medium, seed: 0),
                    gameMode: .classic,
                    progressStore: captureProgress
                )
            }

        case .mechanic:
            catalogGame(levelIndex: Self.requestedLevelIndex ?? 68, combo: nil, clearedMoveCount: 0)

        case .combo:
            catalogGame(levelIndex: 82, combo: 5, clearedMoveCount: 10)

        case .worlds:
            NavigationStack {
                WorldMapView()
            }
            .screenshotReadyAfterLayout()

        case .daily:
            ScreenshotDailyGameView(progressStore: captureProgress)

        case .quests:
            DailyQuestsView()
                .screenshotReadyAfterLayout()
        }
    }

    @ViewBuilder
    private func catalogGame(
        levelIndex: Int,
        combo: Int?,
        clearedMoveCount: Int
    ) -> some View {
        if let sourceLevel = levelCatalog.level(at: levelIndex) {
            let level = clearedMoveCount > 0
                ? Self.level(
                    sourceLevel,
                    afterRemovingFirstSolvedMoves: clearedMoveCount
                )
                : sourceLevel

            NavigationStack {
                ScreenshotGameView(
                    level: level,
                    mode: .story(index: levelIndex),
                    gameMode: .classic,
                    progressStore: captureProgress,
                    combo: combo,
                    movesMade: clearedMoveCount
                )
            }
        } else {
            ProgressView("Loading levels…")
                .task {
                    await levelCatalog.loadIfNeeded()
                }
        }
    }

    /// QA can inspect an actual bundled continuation level without unlocking
    /// or rewriting the user's campaign. The harness uses its own defaults.
    private static var requestedLevelIndex: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--screenshot-level"),
              arguments.indices.contains(flag + 1),
              let index = Int(arguments[flag + 1]), (241...260).contains(index) else { return nil }
        return index
    }

    private static func level(
        _ source: Level,
        afterRemovingFirstSolvedMoves count: Int
    ) -> Level {
        // Gate opening depends on the original key set. A reduced Level is
        // not a resumable Board and must not pretend its removed keys never
        // existed. Keep new gate fixtures intact until captures replay moves.
        guard source.rulesVersion == 1 else { return source }
        guard count > 0,
              let solution = LevelSolver.solve(board: source.makeBoard())
        else { return source }

        let removedIDs = Set(solution.prefix(count))
        return Level(
            id: "\(source.id)_screenshot_\(count)",
            index: source.index,
            difficulty: source.difficulty,
            width: source.width,
            height: source.height,
            lives: source.lives,
            pieces: source.pieces.filter { !removedIDs.contains($0.id) },
            piecePalette: source.piecePalette,
            obstacles: source.obstacles,
            goal: source.goal,
            threeStarMaxMistakes: source.threeStarMaxMistakes,
            twoStarMaxMistakes: source.twoStarMaxMistakes,
            name: source.name,
            rulesVersion: source.rulesVersion
        )
    }

    private static func progressFixture(
        for scene: ScreenshotCaptureScene
    ) -> PlayerProgress {
        var progress = PlayerProgress.initial
        progress.hintsCount = 3
        progress.undosCount = 5
        progress.coins = 420

        switch scene {
        case .worlds:
            let completed = Set(1...200)
            progress.unlockedLevelIndex = 201
            progress.completedLevels = completed
            progress.stars = Dictionary(uniqueKeysWithValues: completed.map { index in
                (index, index.isMultiple(of: 4) ? 2 : 3)
            })
            progress.coins = 1_240

        case .daily, .quests:
            let date = ScreenshotDailyGameView.fixedDate
            let dailyPilgrim = DailyQuest(
                id: "screenshot_daily_0",
                template: .dailyPilgrim,
                progress: 1
            )
            let starHunter = DailyQuest(
                id: "screenshot_daily_1",
                template: .starHunter,
                progress: 1
            )
            let bingeSolver = DailyQuest(
                id: "screenshot_daily_2",
                template: .bingeSolver,
                progress: 3
            )
            progress.dailyStreak = 7
            progress.bestDailyStreak = 12
            progress.lastDailyCompletionDate = "2026-08-15"
            progress.dailyCompletions = ["2026-08-15"]
            progress.dailyQuestState = DailyQuestState(
                date: date,
                quests: [dailyPilgrim, starHunter, bingeSolver],
                claimedRewards: []
            )
            progress.streakFreezes = 1
            progress.claimedStreakChests = [3, 7]

        case .photo, .mechanic, .combo:
            break
        }

        return progress
    }
}

private struct ScreenshotGameView: View {
    @State private var model: GameViewModel

    init(
        level: Level,
        mode: GameViewModel.LevelMode,
        gameMode: GameMode,
        progressStore: ProgressStore,
        combo: Int? = nil,
        movesMade: Int = 0
    ) {
        let model = GameViewModel(
            level: level,
            mode: mode,
            gameMode: gameMode,
            progressStore: progressStore,
            settingsStore: .shared
        )
        if let combo {
            model.prepareForScreenshot(combo: combo, movesMade: movesMade)
        }
        _model = State(initialValue: model)
    }

    var body: some View {
        GameView(model: model)
    }
}

private struct ScreenshotDailyGameView: View {
    static let fixedDate = "2026-08-16"

    let progressStore: ProgressStore
    @State private var level: Level?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let level {
                NavigationStack {
                    ScreenshotGameView(
                        level: level,
                        mode: .daily(date: Self.fixedDate),
                        gameMode: .zenDaily,
                        progressStore: progressStore
                    )
                }
            } else if loadFailed {
                ContentUnavailableView(
                    "Daily puzzle unavailable",
                    systemImage: "exclamationmark.triangle.fill"
                )
            } else {
                ProgressView("Preparing daily puzzle…")
                    .task {
                        do {
                            level = try await DailyPuzzleProvider.shared.puzzle(
                                for: Self.fixedDate
                            )
                        } catch is CancellationError {
                            return
                        } catch {
                            loadFailed = true
                        }
                    }
            }
        }
    }
}

private extension View {
    func screenshotReadyAfterLayout() -> some View {
        task {
            await Task.yield()
            await Task.yield()
            do {
                try await Task.sleep(for: .milliseconds(650))
            } catch {
                return
            }
            ScreenshotCaptureSignal.markReady()
        }
    }
}
#endif
