//
//  ContentView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI

struct ContentView: View {
    @Environment(LevelCatalogStore.self) private var levelCatalog
    @Environment(OnboardingStore.self) private var onboarding
    /// Level decoded from a scanned/tapped mazearrows:// link.
    @State private var sharedLevel: Level?
    @State private var pendingSharedLevel: Level?
    @State private var linkImportTask: Task<Void, Never>?
    @State private var linkImportRequestID = UUID()
    @State private var linkImportFailure: LevelImportError?
    @State private var isShowingLinkImportFailure = false
    #if DEBUG
    @State private var debugIndex: Int? = Self.initialDebugLevel
    #endif

    var body: some View {
        mainContent
            .onAppear {
                PerformanceTrace.initialScreenReady(
                    onboarding.shouldShow ? "onboarding" : "menu"
                )
            }
            .onOpenURL { url in
                guard FeatureFlags.photoMazeSharingAvailable else { return }
                startLinkImport(from: url)
            }
            .onChange(of: onboarding.shouldShow) {
                guard !onboarding.shouldShow, let pendingSharedLevel else { return }
                self.pendingSharedLevel = nil
                sharedLevel = pendingSharedLevel
            }
            .alert(
                "Unable to Open Maze",
                isPresented: $isShowingLinkImportFailure,
                presenting: linkImportFailure
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { failure in
                if failure == .timedOut {
                    Text("Import took too long. Please try again.")
                } else {
                    Text("That link doesn't contain a valid maze.")
                }
            }
            .fullScreenCover(item: $sharedLevel) { level in
                NavigationStack {
                    GameView(model: GameViewModel(
                        level: level,
                        mode: .generated(difficulty: level.difficulty, seed: 0)
                    ))
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                sharedLevel = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel("Close")
                        }
                    }
                }
            }
            .onDisappear(perform: cancelLinkImport)
    }

    private func startLinkImport(from url: URL) {
        cancelLinkImport()
        let input = url.absoluteString
        let requestID = UUID()
        linkImportRequestID = requestID
        linkImportFailure = nil
        isShowingLinkImportFailure = false

        linkImportTask = Task {
            do {
                let level = try await LevelImportService.importLevel(from: input)
                guard !Task.isCancelled, linkImportRequestID == requestID else { return }
                linkImportTask = nil
                if onboarding.shouldShow {
                    pendingSharedLevel = level
                } else {
                    sharedLevel = level
                }
            } catch is CancellationError {
                guard linkImportRequestID == requestID else { return }
                linkImportTask = nil
            } catch let error as LevelImportError {
                guard linkImportRequestID == requestID else { return }
                linkImportTask = nil
                linkImportFailure = error
                isShowingLinkImportFailure = true
            } catch {
                guard linkImportRequestID == requestID else { return }
                linkImportTask = nil
                linkImportFailure = .invalidCode
                isShowingLinkImportFailure = true
            }
        }
    }

    private func cancelLinkImport() {
        linkImportRequestID = UUID()
        linkImportTask?.cancel()
        linkImportTask = nil
    }

    @ViewBuilder
    private var mainContent: some View {
        #if DEBUG
        if let screenshotCapture = ScreenshotCaptureConfiguration.current {
            ScreenshotHarnessView(configuration: screenshotCapture)
        } else if let i = debugIndex {
            if let level = levelCatalog.level(at: i) {
                NavigationStack {
                    GameView(
                        model: GameViewModel(level: level, mode: .story(index: i))
                    ) {
                        // Mimic the real menu flow: advance to next story level.
                        debugIndex = levelCatalog.level(at: i + 1) != nil ? i + 1 : nil
                    }
                    .id(i)
                }
            } else {
                ProgressView("Loading levels…")
                    .task {
                        await levelCatalog.loadIfNeeded()
                    }
            }
        } else if onboarding.shouldShow {
            OnboardingFlowView()
        } else {
            MainMenuView(initialRoute: initialMenuRoute)
        }
        #else
        if onboarding.shouldShow {
            OnboardingFlowView()
        } else {
            MainMenuView(initialRoute: initialMenuRoute)
        }
        #endif
    }

    private var initialMenuRoute: MainMenuView.Route? {
        switch onboarding.exitDestination {
        case .levelFive: return .story(5)
        case .worldMap: return .worldMap
        case nil: return nil
        }
    }

    #if DEBUG
    private static var initialDebugLevel: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--debug-level"),
              i + 1 < args.count,
              let value = Int(args[i + 1]) else { return nil }
        return value
    }
    #endif
}

#Preview {
    ContentView()
        .environment(SettingsStore.shared)
        .environment(ProgressStore.shared)
        .environment(LevelCatalogStore.shared)
        .environment(OnboardingStore(progressStore: .shared))
        .environment(PremiumStore())
        .environment(GameCenterStore())
        .environment(AdService())
        .environment(ReviewRequestStore())
        .environment(AppIconStore())
}
