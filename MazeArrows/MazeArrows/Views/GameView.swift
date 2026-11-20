//
//  GameView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import SwiftUI
import SpriteKit
import StoreKit
import UIKit

struct GameView: View {
    @State private var model: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Environment(PremiumStore.self) private var premium
    @Environment(AdService.self) private var ads
    @Environment(ProgressStore.self) private var progress
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(ReviewRequestStore.self) private var reviewRequests
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var sceneContainer = SceneContainer()
    @State private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    @State private var premiumPaywallContext: PremiumPaywallContext?
    @State private var opensHintPaywallAfterOfferDismisses = false
    @State private var hasResolvedCompletionPresentation = false
    let onNext: (() -> Void)?

    init(model: GameViewModel, onNext: (() -> Void)? = nil) {
        _model = State(initialValue: model)
        self.onNext = onNext
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }

    private var shouldExposeAccessibleBoard: Bool {
        if isVoiceOverRunning { return true }
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--debug-accessibility-game-board")
        #else
        return false
        #endif
    }

    private var reduceMotionEnabled: Bool {
        if accessibilityReduceMotion { return true }
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--debug-reduce-motion")
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            theme.appBackground
                .ignoresSafeArea()

            VStack(spacing: 8) {
                gameHUD

                if model.hasKeyGates {
                    if model.isGateTraining {
                        Label(String(localized: "Practice: mistakes cost no hearts", table: "Gates"), systemImage: "shield.checkered")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundStyle(theme.inkMuted)
                            .padding(.horizontal, 18)
                    }
                    if model.gateGuidance != nil {
                        gateGuidanceView
                            .padding(.horizontal, 18)
                    }
                }

                GeometryReader { proxy in
                    let sceneSize = fittedSceneSize(for: model.level, in: proxy.size)
                    let scene = sceneContainer.scene(
                        for: model.level,
                        theme: theme,
                        increasedContrast: colorSchemeContrast == .increased,
                        showsArrowOutlines: settings.settings.arrowOutlinesEnabled,
                        arrowOutlineColor: settings.settings.arrowOutlineColor,
                        size: sceneSize,
                        reduceMotion: reduceMotionEnabled,
                        delegate: model,
                        onPreparationStarted: {
                            PerformanceTrace.beginLevelLoad(
                                contentID: analyticsContentID,
                                mode: analyticsMode
                            )
                        },
                        onReady: {
                            PerformanceTrace.levelReady(
                                contentID: analyticsContentID,
                                mode: analyticsMode
                            )
                            model.presentGateTrainingFocus()
                        },
                        bind: {
                            model.scene = $0
                            $0.accessibilityElementsDidChange = { [weak model] in
                                model?.accessibilityBoardDidChange()
                            }
                        }
                    )
                    ZStack {
                        SpriteView(
                            scene: scene,
                            options: [.shouldCullNonVisibleNodes]
                        )
                        .accessibilityRepresentation {
                            EmptyView()
                        }

                        if shouldExposeAccessibleBoard {
                            GameBoardAccessibilityLayer(
                                scene: scene,
                                sceneSize: sceneSize,
                                revision: model.accessibilityBoardRevision
                            )
                        }
                    }
                    .frame(width: sceneSize.width, height: sceneSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .id(sceneIdentity)
                }
                .padding(.horizontal, 14)

                if !goalSummary.isEmpty {
                    goalChip
                        .padding(.top, 2)
                }

                actionBar
                    .padding(.bottom, 12)
            }
            .padding(.top, 4)
            .accessibilityHidden(model.isCompleted || model.isFailed)

        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(
            item: Bindable(model).resourceOffer,
            onDismiss: openPendingHintPaywall
        ) { offer in
            ResourceOfferSheet(
                model: model,
                offer: offer,
                theme: theme,
                openPremium: {
                    opensHintPaywallAfterOfferDismisses = true
                    model.dismissResourceOffer()
                }
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $premiumPaywallContext) { context in
            PremiumPaywallView(context: context) {
                if context == .hints {
                    model.continueHintAfterPremiumUnlock()
                }
            }
        }
        .onChange(of: premiumPaywallContext) { _, context in
            if context != nil {
                model.recordCommercialInterruption()
            }
        }
        .task {
            await model.runSessionTimer()
        }
        .onChange(of: premium.isPremium, initial: true) { _, isPremium in
            guard premium.hasLoadedEntitlements else { return }
            model.updatePremiumAccess(
                PremiumAccessPolicy(isPremium: isPremium)
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIAccessibility.voiceOverStatusDidChangeNotification
            )
        ) { _ in
            isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        }
        .overlay {
            if model.isCompleted {
                if hasResolvedCompletionPresentation {
                    WinOverlayView(
                        model: model,
                        theme: theme,
                        onReplay: restartGame,
                        onClose: closeGame,
                        onNext: nextAction
                    )
                    .transition(.opacity)
                } else {
                    LevelCompleteTransitionView(theme: theme)
                        .transition(.opacity)
                }
            } else if model.isFailed {
                FailOverlayView(
                    model: model,
                    theme: theme,
                    onRevive: { model.requestRevive() },
                    onRetry: restartGame,
                    onClose: closeGame
                )
                .transition(.opacity)
            }
        }
        .animation(
            reduceMotionEnabled ? nil : .easeInOut(duration: 0.2),
            value: model.isCompleted
        )
        .animation(
            reduceMotionEnabled ? nil : .easeInOut(duration: 0.2),
            value: model.isFailed
        )
        .overlay(alignment: .top) {
            if let achievementId = model.pendingAchievementBanner,
               let achievement = Achievement.find(achievementId) {
                Button {
                    model.dismissAchievementBanner()
                } label: {
                    AchievementBannerView(achievement: achievement, theme: theme)
                }
                    .buttonStyle(.plain)
                    .padding(.top, 56)
                    .transition(
                        reduceMotionEnabled
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity)
                    )
                    .accessibilityLabel(Text("Achievement unlocked: \(achievement.title)"))
                    .accessibilityHint("Double-tap to dismiss.")
                    .task(id: achievementId) {
                        do {
                            try await Task.sleep(for: .seconds(3))
                        } catch {
                            return
                        }
                        guard model.pendingAchievementBanner == achievementId else { return }
                        model.dismissAchievementBanner()
                    }
            }
        }
        .animation(
            reduceMotionEnabled ? nil : .spring(duration: 0.4),
            value: model.pendingAchievementBanner
        )
        .onAppear {
            model.beginSession()
            Analytics.log(.levelStarted(
                contentID: analyticsContentID,
                mode: analyticsMode
            ))
            postVoiceOverScreenChange(
                String(localized: "\(modeLabel) \(levelTitle). \(model.level.pieces.count) arrows.")
            )
        }
        .onDisappear {
            model.endSession()
        }
        .onChange(of: model.isCompleted) { _, completed in
            if completed {
                Analytics.log(.levelCompleted(
                    contentID: analyticsContentID,
                    mode: analyticsMode,
                    durationSeconds: model.elapsedSeconds,
                    mistakes: model.mistakesCount,
                    hintsUsed: model.hintsUsed,
                    maxCombo: model.maxCombo
                ))
                postVoiceOverScreenChange(String(localized: "Level cleared."))
            }
        }
        .onChange(of: model.isFailed) { _, failed in
            if failed {
                Analytics.log(.levelFailed(
                    contentID: analyticsContentID,
                    mode: analyticsMode,
                    durationSeconds: model.elapsedSeconds,
                    reason: model.failReason?.analyticsIdentifier ?? "unknown"
                ))
                postVoiceOverScreenChange(String(localized: "Level failed."))
            }
        }
        .onChange(of: model.secondsRemaining) { _, seconds in
            guard model.hasTimer,
                  [15, 10, 5, 4, 3, 2, 1].contains(seconds),
                  UIAccessibility.isVoiceOverRunning
            else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: String(localized: "\(seconds) seconds remaining.")
            )
        }
        .task(id: model.isCompleted) {
            await resolveCompletionPresentation()
        }
        #if DEBUG
        .task(id: model.isCompleted) {
            guard model.isCompleted,
                  ProcessInfo.processInfo.arguments.contains("--debug-auto-next"),
                  let onNext
            else { return }
            do {
                try await Task.sleep(for: .milliseconds(1_500))
            } catch {
                return
            }
            guard !Task.isCancelled, model.isCompleted else { return }
            model.endSession()
            onNext()
        }
        #endif
    }

    private func resolveCompletionPresentation() async {
        guard model.isCompleted else {
            hasResolvedCompletionPresentation = false
            return
        }

        if scenePhase == .active,
           !ProcessInfo.processInfo.arguments.contains("--debug-auto-next"),
           let opportunity = reviewOpportunity,
           let reservation = reviewRequests.reserve(opportunity: opportunity) {
            _ = ads.registerInterstitialOpportunity(
                isFirstStoryCompletion: model.isFirstStoryCompletion,
                allowsPresentation: false
            )
            hasResolvedCompletionPresentation = true
            await requestReviewAfterCelebration(reservation)
            return
        }

        let allowsPresentation = model.pendingAchievementBanner == nil
            && !ProcessInfo.processInfo.arguments.contains("--debug-auto-next")
        let shouldPresent = ads.registerInterstitialOpportunity(
            isFirstStoryCompletion: model.isFirstStoryCompletion,
            allowsPresentation: allowsPresentation
        )

        guard shouldPresent else {
            hasResolvedCompletionPresentation = true
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(800))
        } catch {
            return
        }
        guard !Task.isCancelled, model.isCompleted else { return }

        _ = ads.presentInterstitialIfReady()
        hasResolvedCompletionPresentation = true
    }

    private func requestReviewAfterCelebration(
        _ reservation: ReviewRequestStore.Reservation
    ) async {
        var committed = false
        defer {
            if !committed {
                reviewRequests.cancel(reservation)
            }
        }

        do {
            try await Task.sleep(for: .milliseconds(1_800))
            var waitedForAchievement = false
            while model.pendingAchievementBanner != nil {
                waitedForAchievement = true
                try await Task.sleep(for: .milliseconds(200))
            }
            if waitedForAchievement {
                try await Task.sleep(for: .milliseconds(350))
            }
        } catch {
            return
        }

        guard !Task.isCancelled,
              model.isCompleted,
              !model.hasUsedRevive,
              !model.hadCommercialInterruption,
              model.resourceOffer == nil,
              premiumPaywallContext == nil,
              scenePhase == .active,
              !ads.isPresentingInterstitial,
              !ads.isPresentingRewardedAd,
              reviewRequests.commit(reservation)
        else { return }

        committed = true
        requestReview()
    }

    private var reviewOpportunity: ReviewRequestOpportunity? {
        let trigger: ReviewRequestTrigger

        switch model.mode {
        case .story(let index):
            let completedChapter = Chapter.all.contains {
                $0.levelRange.upperBound == index
                    && $0.isComplete(progress: progress.progress)
            }
            trigger = completedChapter ? .chapterCompleted : .storyClear
        case .daily:
            guard progress.progress.dailyStreak >= 3 else { return nil }
            trigger = .threeDayStreak
        case .generated:
            trigger = .photoMazeCompleted
        case .weekly, .zen, .master:
            return nil
        }

        return ReviewRequestOpportunity(
            trigger: trigger,
            completedStoryLevelsAfterOnboarding: progress.progress.completedLevels
                .filter { $0 >= 5 }
                .count,
            onboardingCompleted: !onboarding.shouldShow,
            isFirstCompletion: model.isFirstStoryCompletion,
            stars: model.earnedStars,
            hasUsedRevive: model.hasUsedRevive,
            hadCommercialInterruption: model.hadCommercialInterruption,
            streakDays: progress.progress.dailyStreak
        )
    }

    private func openPendingHintPaywall() {
        guard opensHintPaywallAfterOfferDismisses else { return }
        opensHintPaywallAfterOfferDismisses = false
        premiumPaywallContext = .hints
    }

    private var nextAction: (() -> Void)? {
        guard let onNext else { return nil }
        return {
            model.endSession()
            onNext()
        }
    }

    private func closeGame() {
        model.endSession()
        dismiss()
    }

    private func restartGame() {
        Analytics.log(.levelRestarted(
            contentID: analyticsContentID,
            mode: analyticsMode
        ))
        hasResolvedCompletionPresentation = false
        model.restart()
    }

    private var analyticsContentID: String {
        model.mode.analyticsContentIdentifier
    }

    private var analyticsMode: String {
        model.mode.analyticsModeIdentifier
    }

    private func postVoiceOverScreenChange(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        Task { @MainActor in
            await Task.yield()
            UIAccessibility.post(notification: .screenChanged, argument: message)
        }
    }

    // MARK: - game HUD

    private var gateGuidanceView: some View {
        HStack(alignment: .top, spacing: 8) {
            if let message = model.gateGuidance {
                Text(verbatim: message)
                    .scaledFont(size: 13, weight: .medium)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                Button {
                    model.dismissGateGuidance()
                } label: {
                    Image(systemName: "xmark")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text(String(localized: "Dismiss gate explanation", table: "Gates")))
            }
        }
        .padding(.leading, 14)
        .foregroundStyle(theme.ink)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var gameHUD: some View {
        let usesAccessibilityLayout = dynamicTypeSize.isAccessibilitySize
        let horizontalAlignment: HorizontalAlignment = usesAccessibilityLayout ? .leading : .center
        let contentAlignment: Alignment = usesAccessibilityLayout ? .leading : .center
        let comboStyle = ComboHUDAnimationStyle.style(for: model.combo)

        return ZStack(alignment: .topLeading) {
            ZStack(alignment: contentAlignment) {
                ComboHUDSwitcher(
                    isShowingCombo: model.showComboBurst,
                    combo: model.combo,
                    callout: model.comboCallout,
                    style: comboStyle,
                    theme: theme,
                    reduceMotion: reduceMotionEnabled,
                    alignment: contentAlignment
                ) {
                    VStack(alignment: horizontalAlignment, spacing: 8) {
                        levelHeader(alignment: horizontalAlignment)
                        statusBar
                    }
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
                }
                .id(comboStyle)
                .transition(
                    reduceMotionEnabled ? .opacity : comboStyle.milestoneTransition
                )
            }
            .animation(
                reduceMotionEnabled
                    ? .easeInOut(duration: 0.15)
                    : comboStyle.milestoneAnimation,
                value: comboStyle
            )
            .padding(.leading, usesAccessibilityLayout ? 56 : 52)
            .padding(.trailing, usesAccessibilityLayout ? 0 : 52)

            CircleIconButton(systemImage: "chevron.left", theme: theme) {
                closeGame()
            }
        }
        .overlay(alignment: .topTrailing) {
            if model.hasKeyGates {
                CircleIconButton(systemImage: "info.circle", theme: theme) {
                    model.showGateRules()
                }
                .accessibilityLabel(Text(String(localized: "Gate rules", table: "Gates")))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func levelHeader(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(modeLabel)
                .textCase(.uppercase)
                .scaledFont(size: 11, weight: .bold)
                .tracking(1.2)
                .foregroundStyle(theme.inkMuted)
            Text(levelTitle)
                .scaledFont(size: 22, weight: .heavy)
                .foregroundStyle(theme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(modeLabel) \(levelTitle)"))
        .accessibilityAddTraits(.isHeader)
    }

    private var levelTitle: String {
        switch model.mode {
        case .story(let index):  return "\(index)"
        case .daily:             return String(localized: "Daily")
        case .weekly:            return String(localized: "Weekly")
        case .generated:         return String(localized: "Custom")
        case .zen(_, let index): return "\(index + 1)"
        case .master(let index): return "\(index)"
        }
    }

    private var modeLabel: String {
        if case .zen = model.mode {
            return String(localized: "Zen")
        }
        if case .master = model.mode {
            return String(localized: "Master · \(model.gameMode.displayName)")
        }
        switch model.gameMode {
        case .classic: return String(localized: "Level")
        default:       return model.gameMode.displayName
        }
    }

    private func fittedSceneSize(for level: Level, in available: CGSize) -> CGSize {
        let safeWidth = max(1, available.width)
        let safeHeight = max(1, available.height)
        let boardAspect = CGFloat(level.width) / CGFloat(max(level.height, 1))
        let availableAspect = safeWidth / safeHeight

        if availableAspect > boardAspect {
            return CGSize(width: safeHeight * boardAspect, height: safeHeight)
        } else {
            return CGSize(width: safeWidth, height: safeWidth / boardAspect)
        }
    }

    private var sceneIdentity: String {
        let outline = settings.settings.arrowOutlineColor
        return "\(model.level.id)-\(settings.settings.themeID.rawValue)-\(colorSchemeContrast == .increased)-\(settings.settings.arrowOutlinesEnabled)-\(outline.red)-\(outline.green)-\(outline.blue)"
    }

    // MARK: - status bar

    @ViewBuilder
    private var statusBar: some View {
        if model.isGateTraining {
            EmptyView()
        } else if model.usesLives && !model.hasTimer {
            HeartsView(total: model.totalLives, filled: model.lives, theme: theme)
        } else if model.hasTimer {
            timerView
        } else {
            // peaceful — show a chip with the mode
            DynamicTypeStack(spacing: 6) {
                Image(systemName: model.gameMode.systemImage)
                Text(model.gameMode.subtitle)
                    .scaledFont(size: 12, weight: .semibold)
                    .tracking(0.5)
            }
            .foregroundStyle(theme.inkMuted)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(model.gameMode.displayName))
            .accessibilityValue(Text(model.gameMode.subtitle))
        }
    }

    private var timerView: some View {
        let warn = model.secondsRemaining <= 15
        return HStack(spacing: 8) {
            Image(systemName: warn ? "exclamationmark.triangle.fill" : "timer")
                .scaledFont(size: 16, weight: .bold)
                .foregroundStyle(warn ? theme.danger : theme.inkSoft)
            Text(model.formattedCountdown)
                .scaledFont(size: 22, weight: .black, design: .rounded)
                .foregroundStyle(warn ? theme.danger : theme.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(theme.surface)
                .overlay(Capsule().stroke(warn ? theme.danger.opacity(0.4) : theme.glassBorder))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue(Text(model.formattedCountdown))
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - goal chip

    private var goalSummary: String {
        switch model.level.goal {
        case .clearAll: return ""
        default: return model.level.goal.displayText
        }
    }

    private var goalChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "target")
                .scaledFont(size: 11, weight: .bold)
            Text(goalSummary)
                .scaledFont(size: 12, weight: .semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(theme.inkSoft)
        .background(
            Capsule()
                .fill(theme.surface)
                .overlay(Capsule().stroke(theme.glassBorder))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal")
        .accessibilityValue(Text(goalSummary))
    }

    // MARK: - action bar

    @ViewBuilder
    private var actionBar: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal, showsIndicators: false) {
                actionButtons
                    .padding(.horizontal, 16)
            }
        } else {
            actionButtons
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 30) {
            ActionPillView(
                systemImage: model.gameMode.allowsHints ? "lightbulb.fill" : "lock.fill",
                label: "Hint",
                badge: model.gameMode.allowsHints
                    ? (model.hasUnlimitedHints ? "∞" : "\(model.availableHints)")
                    : nil,
                isDisabled: model.isCompleted || model.isFailed || !model.gameMode.allowsHints,
                voiceOverHint: "Highlights a recommended arrow.",
                theme: theme
            ) {
                model.consumeHint()
            }
            ActionPillView(
                systemImage: model.gameMode.allowsUndo ? "arrow.uturn.backward" : "lock.fill",
                label: "Undo",
                badge: model.gameMode.allowsUndo ? "\(model.availableUndos)" : nil,
                isDisabled: model.isCompleted || model.isFailed || model.movesMade == 0 || !model.gameMode.allowsUndo,
                voiceOverHint: "Restores the last cleared arrow.",
                theme: theme
            ) {
                model.consumeUndo()
            }
            ActionPillView(
                systemImage: "arrow.clockwise",
                label: "Restart",
                isDisabled: false,
                voiceOverHint: "Restarts the current level.",
                theme: theme
            ) {
                restartGame()
            }
        }
    }
}

/// SwiftUI's SpriteKit bridge does not forward custom accessibility children
/// from `SKView`. This transparent layer is mounted only while VoiceOver runs,
/// leaving the normal touch and gesture path completely unchanged.
private struct GameBoardAccessibilityLayer: View {
    let scene: GameScene
    let sceneSize: CGSize
    let revision: UInt

    private var orderedPieces: [ArrowPiece] {
        scene.board.pieces.sorted {
            if $0.headCell.y == $1.headCell.y {
                return $0.headCell.x < $1.headCell.x
            }
            return $0.headCell.y < $1.headCell.y
        }
    }

    private var orderedKeyGates: [Obstacle] {
        scene.board.obstacles.filter { $0.kind == .keyGate }.sorted {
            if $0.cell.y == $1.cell.y { return $0.cell.x < $1.cell.x }
            return $0.cell.y < $1.cell.y
        }
    }

    var body: some View {
        let geometry = BoardGeometry(
            boardWidth: scene.board.width,
            boardHeight: scene.board.height,
            availableSize: sceneSize
        )
        let targetSize = max(44, geometry.cellSize)
        let _ = revision

        ZStack {
            Text("Game board")
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Game board")
                .accessibilityValue(Text("\(orderedPieces.count) arrows"))
                .accessibilityAddTraits(.isHeader)
                .position(x: 1, y: 1)

            ForEach(orderedPieces) { piece in
                AccessibleGamePieceButton(
                    scene: scene,
                    piece: piece,
                    targetSize: targetSize
                )
                .position(position(for: piece, geometry: geometry))
            }

            ForEach(orderedKeyGates) { gate in
                Button {
                    _ = scene.inspectKeyGate(id: gate.id)
                } label: {
                    Color.white.opacity(0.02)
                        .frame(width: targetSize, height: targetSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("game-gate-\(gate.id)")
                .accessibilityLabel(Text(scene.keyGateAccessibilityLabel(for: gate)))
                .accessibilityValue(Text(scene.keyGateAccessibilityValue(for: gate)))
                .accessibilityHint(Text(String(localized: "Double-tap to inspect its key and connected gates. No move is made.", table: "Gates")))
                .position(position(for: gate.cell, geometry: geometry))
            }
        }
        .frame(width: sceneSize.width, height: sceneSize.height)
    }

    private func position(for piece: ArrowPiece, geometry: BoardGeometry) -> CGPoint {
        position(for: piece.headCell, geometry: geometry)
    }

    private func position(for cell: GridPoint, geometry: BoardGeometry) -> CGPoint {
        let scenePoint = geometry.point(for: cell)
        return CGPoint(x: scenePoint.x, y: sceneSize.height - scenePoint.y)
    }
}

private struct AccessibleGamePieceButton: View {
    let scene: GameScene
    let piece: ArrowPiece
    let targetSize: CGFloat

    var body: some View {
        Button {
            _ = scene.activateAccessiblePiece(id: piece.id)
        } label: {
            Color.white.opacity(0.02)
                .frame(width: targetSize, height: targetSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("game-piece-\(piece.id)")
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityHint(Text(accessibilityHint))
        .accessibilityActions {
            Button("Describe path") {
                _ = scene.describeAccessiblePath(for: piece.id)
            }
            if !scene.board.keyGates(forKeyID: piece.id).isEmpty {
                Button {
                    _ = scene.inspectAccessibleKeyGates(forKeyID: piece.id)
                } label: {
                    Text(String(localized: "Inspect connected gates", table: "Gates"))
                }
            }
            if piece.kind == .double {
                Button {
                    _ = scene.activateAccessiblePiece(id: piece.id, direction: piece.direction)
                } label: {
                    Text("Move \(directionName(piece.direction))")
                }
                if let secondaryDirection = piece.secondaryDirection {
                    Button {
                        _ = scene.activateAccessiblePiece(
                            id: piece.id,
                            direction: secondaryDirection
                        )
                    } label: {
                        Text("Move \(directionName(secondaryDirection))")
                    }
                }
            }
        }
    }

    private var accessibilityLabel: String {
        String(localized: "\(kindName(piece.kind)), pointing \(directionName(piece.direction))")
    }

    private var accessibilityValue: String {
        let pathState = MoveValidator.canFlyOut(piece: piece, board: scene.board)
            ? String(localized: "Path clear")
            : String(localized: "Path blocked")
        var parts = [
            String(localized: "Row \(piece.headCell.y + 1), column \(piece.headCell.x + 1)"),
            String(localized: "\(piece.cells.count) cells"),
            pathState
        ]
        if piece.kind == .double, let secondaryDirection = piece.secondaryDirection {
            parts.insert(
                String(localized: "Second direction \(directionName(secondaryDirection))"),
                at: 1
            )
        }
        if piece.kind == .fragile, piece.crackLevel > 0 {
            parts.append(String(localized: "Cracked"))
        }
        if let gateDescription = scene.keyGateKeyAccessibilityValue(forKeyID: piece.id) {
            parts.append(gateDescription)
        }
        return parts.joined(separator: ". ")
    }

    private var accessibilityHint: String {
        if !scene.board.keyGates(forKeyID: piece.id).isEmpty {
            return String(localized: "Double-tap to move. Use Actions to inspect connected gates or describe the path.", table: "Gates")
        }
        if piece.kind == .double {
            return String(
                localized: "Double-tap to use \(directionName(piece.direction)). Use Actions to choose a direction or describe the path."
            )
        }
        return String(localized: "Double-tap to move. Use Actions to describe the path.")
    }

    private func directionName(_ direction: Direction) -> String {
        switch direction {
        case .up: return String(localized: "up")
        case .down: return String(localized: "down")
        case .left: return String(localized: "left")
        case .right: return String(localized: "right")
        }
    }

    private func kindName(_ kind: PieceKind) -> String {
        switch kind {
        case .standard: return String(localized: "Arrow")
        case .heavy: return String(localized: "Heavy arrow")
        case .fragile: return String(localized: "Fragile arrow")
        case .frozen: return String(localized: "Frozen arrow")
        case .double: return String(localized: "Double-direction arrow")
        case .lockedLock: return String(localized: "Locked arrow")
        case .lockedKey: return String(localized: "Key arrow")
        case .bomb: return String(localized: "Bomb arrow")
        case .chain: return String(localized: "Chain arrow")
        }
    }
}

// MARK: - helpers

struct CircleIconButton: View {
    let systemImage: String
    let theme: GameTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .scaledFont(size: 16, weight: .bold)
                .foregroundStyle(theme.inkSoft)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(theme.surface)
                        .overlay(Circle().stroke(theme.glassBorder))
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .minimumTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

// MARK: - SceneContainer

@MainActor
final class SceneContainer {
    private var cached: (
        levelId: String,
        themeId: AppThemeID,
        increasedContrast: Bool,
        showsArrowOutlines: Bool,
        arrowOutlineColor: PieceGroupPaletteColor,
        size: CGSize,
        scene: GameScene
    )?

    func scene(
        for level: Level,
        theme: GameTheme,
        increasedContrast: Bool,
        showsArrowOutlines: Bool,
        arrowOutlineColor: PieceGroupPaletteColor,
        size: CGSize,
        reduceMotion: Bool,
        delegate: GameSceneDelegate,
        onPreparationStarted: () -> Void,
        onReady: @escaping () -> Void,
        bind: (GameScene) -> Void
    ) -> GameScene {
        if let cached, cached.levelId == level.id,
           cached.themeId == theme.id,
           cached.increasedContrast == increasedContrast,
           cached.showsArrowOutlines == showsArrowOutlines,
           cached.arrowOutlineColor == arrowOutlineColor,
           cached.size == size || level.rulesVersion == 2 {
            if cached.scene.view == nil {
                onPreparationStarted()
            }
            cached.scene.sceneDelegate = delegate
            cached.scene.didPrepareForDisplay = onReady
            bind(cached.scene)
            cached.scene.setReduceMotion(reduceMotion)
            if cached.size != size {
                // Gate guidance changes the available height. Keep the live
                // board (including its original key IDs) and the VM's move
                // history together instead of constructing the initial level
                // again. didChangeSize resolves in-flight actions and redraws
                // the same Board at its new geometry.
                cached.scene.size = size
                self.cached?.size = size
            }
            return cached.scene
        }
        onPreparationStarted()
        let scene = GameScene(
            level: level,
            theme: theme,
            size: size,
            showsArrowOutlines: showsArrowOutlines,
            arrowOutlineColor: arrowOutlineColor,
            reduceMotion: reduceMotion
        )
        scene.sceneDelegate = delegate
        scene.didPrepareForDisplay = onReady
        bind(scene)
        cached = (
            level.id,
            theme.id,
            increasedContrast,
            showsArrowOutlines,
            arrowOutlineColor,
            size,
            scene
        )
        return scene
    }
}
