//
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//App.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

@main
struct MazeArrowsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = SettingsStore.shared
    @State private var progress = ProgressStore.shared
    @State private var levelCatalog = LevelCatalogStore.shared
    @State private var onboarding = OnboardingStore(progressStore: .shared)
    @State private var gameCenter = GameCenterStore()
    @State private var reviewRequests = ReviewRequestStore()
    @State private var appIcons = AppIconStore()

    init() {
        PerformanceTrace.appDidStart()
        #if DEBUG
        if ScreenshotCaptureConfiguration.current != nil {
            var captureSettings = SettingsStore.shared.settings
            captureSettings.soundEnabled = false
            captureSettings.hapticsEnabled = false
            captureSettings.themeID = .neon
            captureSettings.previewPathEnabled = true
            captureSettings.arrowOutlinesEnabled = false
            captureSettings.hintDepth = 2
            SettingsStore.shared.settings = captureSettings
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(progress)
                .environment(levelCatalog)
                .environment(onboarding)
                .environment(gameCenter)
                .environment(reviewRequests)
                .environment(appIcons)
                .preferredColorScheme(settings.settings.themeID == .neon ? .dark : .light)
                .fullScreenCover(item: gameCenterAuthenticationRequest) { request in
                    GameCenterAuthenticationView(
                        viewController: request.viewController
                    )
                    .ignoresSafeArea()
                    .interactiveDismissDisabled()
                }
                .task {
                    if !Self.isRunningUnitTests && !Self.isScreenshotCaptureActive {
                        gameCenter.start()
                    }
                }
                .task {
                    await levelCatalog.loadIfNeeded()
                }
                .onChange(of: settings.settings.themeID) { _, themeID in
                    guard !Self.isScreenshotCaptureActive else { return }
                    guard !onboarding.shouldShow else { return }
                    let iconStore = appIcons
                    let settingsStore = settings
                    Task { @MainActor [iconStore, settingsStore] in
                        // Let the theme and preferred color scheme finish
                        // their render transaction before presenting UI.
                        await Task.yield()
                        guard settingsStore.settings.themeID == themeID else { return }
                        iconStore.offerMatchingIcon(for: themeID)
                    }
                }
                .onChange(of: settings.settings.soundEnabled, initial: true) { _, enabled in
                    SoundEffectsPlayer.shared.setEnabled(enabled)
                }
                .onChange(of: leaderboardSnapshot, initial: true) { _, snapshot in
                    guard !Self.isScreenshotCaptureActive else { return }
                    gameCenter.synchronizeLeaderboards(with: snapshot)
                }
                .onChange(of: achievementSnapshot, initial: true) { _, snapshot in
                    guard !Self.isScreenshotCaptureActive else { return }
                    gameCenter.synchronizeAchievements(with: snapshot)
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard !Self.isScreenshotCaptureActive else {
                        if phase != .active {
                            SoundEffectsPlayer.shared.suspend()
                        }
                        return
                    }
                    if phase == .active {
                        reviewRequests.recordActiveDay()
                        SoundEffectsPlayer.shared.setEnabled(settings.settings.soundEnabled)
                        gameCenter.refreshPlayerState()
                    } else {
                        SoundEffectsPlayer.shared.suspend()
                    }
                }
                .alert(
                    "Match app icon?",
                    isPresented: matchingIconAlertIsPresented,
                    presenting: appIcons.pendingTheme
                ) { theme in
                    Button("Use Icon") {
                        let iconStore = appIcons
                        Task { @MainActor [iconStore] in
                            // Allow the SwiftUI alert to finish dismissing before
                            // UIKit presents its system icon-change confirmation.
                            await Task.yield()
                            iconStore.applyIcon(for: theme)
                        }
                    }
                    Button("Not now", role: .cancel) {
                        appIcons.keepCurrentIcon()
                    }
                } message: { theme in
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "Use the matching %@ icon on your Home Screen?"),
                            theme.displayName
                        )
                    )
                }
                .alert(
                    "Couldn't change the app icon",
                    isPresented: appIconErrorIsPresented
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Your current app icon was kept. Please try again.")
                }
        }
    }

    private var matchingIconAlertIsPresented: Binding<Bool> {
        Binding(
            get: {
                !Self.isScreenshotCaptureActive && appIcons.pendingTheme != nil
            },
            set: { isPresented in
                if !isPresented {
                    appIcons.keepCurrentIcon()
                }
            }
        )
    }

    private var appIconErrorIsPresented: Binding<Bool> {
        Binding(
            get: {
                !Self.isScreenshotCaptureActive && appIcons.isShowingChangeError
            },
            set: { appIcons.isShowingChangeError = $0 }
        )
    }

    private var gameCenterAuthenticationRequest:
        Binding<GameCenterAuthenticationRequest?> {
        Binding(
            get: {
                Self.isScreenshotCaptureActive
                    ? nil
                    : gameCenter.authenticationRequest
            },
            set: { request in
                guard request == nil,
                      let current = gameCenter.authenticationRequest
                else { return }
                gameCenter.authenticationPresentationWasDismissed(id: current.id)
            }
        )
    }

    private var leaderboardSnapshot: GameCenterLeaderboardSnapshot {
        GameCenterLeaderboardSnapshot(progress: progress.progress)
    }

    private var achievementSnapshot: GameCenterAchievementSnapshot {
        GameCenterAchievementSnapshot(
            earnedAchievements: progress.progress.earnedAchievements
        )
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static var isScreenshotCaptureActive: Bool {
        #if DEBUG
        ScreenshotCaptureConfiguration.current != nil
        #else
        false
        #endif
    }
}
