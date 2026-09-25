//
//  GameViewModel.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class GameViewModel: GameSceneDelegate {

    enum LevelMode: Equatable {
        case story(index: Int)
        case daily(date: String)
        case weekly(week: String)
        case generated(difficulty: Difficulty, seed: UInt64)
        /// Endless generated flow. Counts toward the daily free limit,
        /// never grants rewards.
        case zen(date: String, index: Int)
        /// Replay of a completed story level with a master modifier
        /// (challenge / timed / hard). One-time crown + coin reward.
        case master(index: Int)

        var analyticsModeIdentifier: String {
            switch self {
            case .story:     return "story"
            case .daily:     return "daily"
            case .weekly:    return "weekly"
            case .generated: return "generated"
            case .zen:       return "zen"
            case .master:    return "master"
            }
        }

        var analyticsContentIdentifier: String {
            switch self {
            case .story(let index):
                return "story:\(index)"
            case .daily(let date):
                return "daily:\(date)"
            case .weekly(let week):
                return "weekly:\(week)"
            case .generated(let difficulty, let seed):
                return "generated:\(difficulty.rawValue):\(seed)"
            case .zen(let date, let index):
                return "zen:\(date):\(index)"
            case .master(let index):
                return "master:\(index)"
            }
        }
    }

    enum FailReason: Equatable, Sendable {
        case outOfLives
        case timeUp
        /// A goal condition (no-mistakes, time target, no-hints) was missed —
        /// unrecoverable, so no revive is offered.
        case goalFailed

        var analyticsIdentifier: String {
            switch self {
            case .outOfLives: return "out_of_lives"
            case .timeUp:     return "time_up"
            case .goalFailed: return "goal_failed"
            }
        }
    }

    /// A resource the player ran out of — drives the offer sheet.
    enum ResourceOffer: String, Identifiable, Equatable, Sendable {
        case hint, undo, revive
        var id: String { rawValue }
    }

    // MARK: state
    private(set) var level: Level
    private(set) var mode: LevelMode
    private(set) var gameMode: GameMode
    private(set) var lives: Int
    private(set) var mistakesCount: Int = 0
    private(set) var movesMade: Int = 0
    private(set) var hintsUsed: Int = 0
    private(set) var isCompleted: Bool = false
    private(set) var isFailed: Bool = false
    private(set) var failReason: FailReason?
    /// Non-nil while the resource offer sheet should be visible.
    /// Settable so the sheet can be dismissed through a binding.
    var resourceOffer: ResourceOffer? {
        didSet {
            guard let offer = resourceOffer, offer != oldValue else { return }
            hadCommercialInterruption = true
            var slots = ["coins"]
            if FeatureFlags.adsAvailable { slots.insert("rewarded", at: 0) }
            if offer == .hint { slots.append("premium") }
            Analytics.log(.offerShown(context: offer.rawValue, slots: slots))
        }
    }
    private(set) var elapsedSeconds: Int = 0
    /// For `.timed`: seconds remaining. Reaches 0 → fail.
    private(set) var secondsRemaining: Int = 0
    private(set) var combo: Int = 0
    private(set) var maxCombo: Int = 0
    private(set) var showComboBurst: Bool = false
    /// Combo callout text — non-nil when a "Sweep!"/"Chain Clear!" is shown.
    private(set) var comboCallout: String?
    private(set) var premiumAccess: PremiumAccessPolicy

    static func shouldPresentComboHUD(for combo: Int) -> Bool {
        combo >= 2
    }

    /// History: pieces removed in order, used by Undo.
    private(set) var moveHistory: [ArrowPiece] = []

    /// Allow taps? Disabled briefly during animations to prevent double-taps.
    private(set) var inputLocked: Bool = false

    /// Newly unlocked achievement to show as a banner (consumed by view).
    private(set) var pendingAchievementBanner: AchievementID?
    /// Total coin balance increase actually granted for this victory.
    private(set) var completionCoinReward: Int = 0
    /// True only when this victory cleared a campaign level for the first time.
    /// Interstitial scheduling deliberately ignores replays and special modes.
    private(set) var isFirstStoryCompletion = false
    /// Prevents review requests after a revive or any monetization surface in
    /// the current level session.
    private(set) var hasUsedRevive = false
    private(set) var hadCommercialInterruption = false
    private(set) var accessibilityBoardRevision: UInt = 0

    weak var scene: GameScene?
    let economyConfig: EconomyConfig
    private let progressStore: ProgressStore
    private let settingsStore: SettingsStore
    private let soundPlayer: SoundEffectsPlayer
    private var sessionGeneration: UInt = 0
    private var isSessionActive = false
    private var isRewardedAdPresentationActive = false
    private var chainedMoveTask: Task<Void, Never>?
    private var comboDismissTask: Task<Void, Never>?

    func accessibilityBoardDidChange() {
        accessibilityBoardRevision &+= 1
    }

    init(
        level: Level,
        mode: LevelMode,
        gameMode: GameMode = .classic,
        progressStore: ProgressStore? = nil,
        settingsStore: SettingsStore? = nil,
        soundPlayer: SoundEffectsPlayer? = nil,
        economyConfig: EconomyConfig? = nil,
        premiumAccess: PremiumAccessPolicy = .free
    ) {
        self.level = level
        self.mode = mode
        self.gameMode = gameMode
        self.economyConfig = economyConfig ?? EconomyConfigStore.shared.config
        let baseLives = max(1, level.lives)
        self.lives = gameMode.livesOverride(levelLives: baseLives) ?? baseLives
        self.secondsRemaining = gameMode.countdownSeconds ?? 0
        self.progressStore = progressStore ?? .shared
        self.settingsStore = settingsStore ?? .shared
        self.soundPlayer = soundPlayer ?? .shared
        self.premiumAccess = premiumAccess
    }

    // MARK: - timer

    func beginSession() {
        isSessionActive = true
        if case .zen(_, let index) = mode {
            Analytics.log(.zenLevelStart(index: index))
        }
    }

    func endSession() {
        isSessionActive = false
        invalidatePendingWork()
        soundPlayer.stop()
        scene?.suspendGameplay()
        scene = nil
    }

    /// Runs only while the owning `GameView` is visible.
    /// The view's `.task` automatically cancels this loop on disappearance.
    func runSessionTimer() async {
        while !Task.isCancelled {
            let generation = sessionGeneration
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            guard isSessionActive else { return }
            guard sessionGeneration == generation else { continue }
            tickTimer()
        }
    }

    private func tickTimer() {
        guard isSessionActive,
              !isCompleted,
              !isFailed,
              resourceOffer == nil,
              !isRewardedAdPresentationActive
        else { return }

        elapsedSeconds += 1
        if gameMode == .timed {
            secondsRemaining = max(0, secondsRemaining - 1)
            if secondsRemaining == 0 {
                declareFailure(reason: .timeUp)
            }
        }
    }

    var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var formattedCountdown: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var hasTimer: Bool { gameMode == .timed }
    var usesLives: Bool { !gameMode.isPeaceful }
    var totalLives: Int {
        gameMode.livesOverride(levelLives: level.lives) ?? max(1, level.lives)
    }
    var availableHints: Int {
        gameMode.allowsHints ? max(0, progressStore.progress.hintsCount) : 0
    }
    var hasUnlimitedHints: Bool {
        gameMode.allowsHints && premiumAccess.hasUnlimitedHints
    }
    var availableUndos: Int {
        gameMode.allowsUndo ? max(0, progressStore.progress.undosCount) : 0
    }

    // MARK: - mutations

    func updatePremiumAccess(_ access: PremiumAccessPolicy) {
        guard premiumAccess != access else { return }
        premiumAccess = access
        if access.hasUnlimitedHints, resourceOffer == .hint {
            resourceOffer = nil
        }
    }

    func restart() {
        invalidatePendingWork()
        soundPlayer.stop()
        isSessionActive = true
        lives = totalLives
        secondsRemaining = gameMode.countdownSeconds ?? 0
        mistakesCount = 0
        movesMade = 0
        hintsUsed = 0
        isCompleted = false
        isFailed = false
        failReason = nil
        resourceOffer = nil
        elapsedSeconds = 0
        combo = 0
        maxCombo = 0
        showComboBurst = false
        comboCallout = nil
        pendingAchievementBanner = nil
        completionCoinReward = 0
        isFirstStoryCompletion = false
        hasUsedRevive = false
        hadCommercialInterruption = false
        moveHistory.removeAll()
        scene?.resetBoard(level.makeBoard())
        scene?.clearAllPreviews()
        inputLocked = false
        announceForVoiceOver(String(localized: "Level restarted. \(level.pieces.count) arrows."))
    }

    func consumeHint() {
        guard isSessionActive else { return }
        guard let scene else { return }
        guard !isCompleted && !isFailed && !inputLocked else { return }
        guard gameMode.allowsHints else {
            triggerHaptic(.warning)
            announceForVoiceOver(String(localized: "Hints are unavailable in this mode."))
            return
        }
        if !premiumAccess.hasUnlimitedHints {
            guard progressStore.consumeHint() else {
                resourceOffer = .hint
                triggerHaptic(.warning)
                announceForVoiceOver(String(localized: "No hints remaining."))
                return
            }
        }
        guard let piece = LevelSolver.nextHintPiece(board: scene.board) else {
            triggerHaptic(.warning)
            announceForVoiceOver(String(localized: "No available move found."))
            return
        }
        hintsUsed += 1
        let depth = settingsStore.settings.hintDepth
        if depth == 1 {
            scene.showHint(level: 1, primary: piece, secondary: nil)
        } else if depth == 3 {
            let order = LevelSolver.solve(board: scene.board) ?? []
            let secondary: ArrowPiece? = order.dropFirst().first.flatMap { id in
                scene.board.pieces.first { $0.id == id }
            }
            scene.showHint(level: 3, primary: piece, secondary: secondary)
        } else {
            scene.showHint(level: 2, primary: piece, secondary: nil)
        }
        triggerHaptic(.light)
        announceForVoiceOver(
            String(localized: "Hint: try the arrow pointing \(piece.direction.rawValue).")
        )
    }

    func consumeUndo() {
        guard isSessionActive else { return }
        guard !isCompleted && !isFailed && !inputLocked else { return }
        guard gameMode.allowsUndo else {
            triggerHaptic(.warning)
            announceForVoiceOver(String(localized: "Undo is unavailable in this mode."))
            return
        }
        guard let last = moveHistory.popLast() else {
            triggerHaptic(.warning)
            announceForVoiceOver(String(localized: "Nothing to undo."))
            return
        }
        guard progressStore.consumeUndo() else {
            moveHistory.append(last)
            resourceOffer = .undo
            triggerHaptic(.warning)
            announceForVoiceOver(String(localized: "No undos remaining."))
            return
        }
        var b = scene?.board ?? level.makeBoard()
        b.append(last)
        scene?.setBoard(b)
        scene?.clearAllPreviews()
        triggerHaptic(.light)
        announceForVoiceOver(String(localized: "Move restored. \(b.pieces.count) arrows remaining."))
    }

    // MARK: - GameSceneDelegate

    func sceneDidTapPiece(_ pieceId: String) {
        guard isSessionActive, !inputLocked, !isCompleted, !isFailed,
              let scene else { return }
        guard let piece = scene.board.pieces.first(where: { $0.id == pieceId }) else { return }

        if MoveValidator.canFlyOut(piece: piece, board: scene.board) {
            successfulMove(piece: piece)
        } else {
            failedTap(piece: piece)
        }
    }

    func sceneDidLongPressPiece(_ pieceId: String) {
        guard isSessionActive,
              gameMode.allowsPathPreview,
              settingsStore.settings.previewPathEnabled,
              !inputLocked, !isCompleted, !isFailed else { return }
        scene?.showPreview(pieceId: pieceId)
    }

    func sceneDidEndLongPress() {
        guard isSessionActive else { return }
        scene?.clearAllPreviews()
    }

    /// For `.double` kind: swiping picks which of the two directions to fire.
    func sceneDidSwipePiece(_ pieceId: String, direction: Direction) {
        guard isSessionActive, !inputLocked, !isCompleted, !isFailed,
              let scene else { return }
        guard var piece = scene.board.pieces.first(where: { $0.id == pieceId }),
              piece.kind == .double else { return }
        let allowed: [Direction] = [piece.direction, piece.secondaryDirection].compactMap { $0 }
        guard allowed.contains(direction) else { return }

        piece.direction = direction
        scene.updatePieceDirection(id: piece.id, direction: direction)

        if MoveValidator.canFlyOut(piece: piece, board: scene.board) {
            successfulMove(piece: piece)
        } else {
            failedTap(piece: piece)
        }
    }

    // MARK: - moves

    private func successfulMove(piece: ArrowPiece) {
        guard isSessionActive else { return }
        let generation = sessionGeneration
        inputLocked = true
        moveHistory.append(piece)
        movesMade += 1
        combo += 1
        maxCombo = max(maxCombo, combo)
        if Self.shouldPresentComboHUD(for: combo) { triggerComboBurst() }
        triggerHaptic(.success)
        playSound(.move)

        applyKindSideEffectsBeforeFlyOut(piece: piece)

        scene?.performFlyOut(pieceId: piece.id) { [weak self] in
            guard let self, self.isCurrentSession(generation) else { return }
            let chainContinues = self.applyKindSideEffectsAfterFlyOut(piece: piece)
            if !chainContinues {
                self.inputLocked = false
                self.checkVictory()
            }
        }
        announceForVoiceOver(
            String(localized: "Arrow cleared. \(scene?.board.pieces.count ?? 0) arrows remaining.")
        )
    }

    private func failedTap(piece: ArrowPiece) {
        guard isSessionActive else { return }
        let generation = sessionGeneration
        inputLocked = true
        mistakesCount += 1
        combo = 0
        triggerHaptic(.warning)
        playSound(.blocked)

        var lifeCost = 1
        var amplify = false
        if piece.kind == .fragile {
            let next = piece.crackLevel + 1
            if next >= 2 {
                lifeCost = 2
                amplify = true
                scene?.updatePieceCrack(id: piece.id, level: 2)
                if let head = scene?.board.piece(at: piece.headCell) {
                    scene?.runExplosion(at: head.headCell)
                }
            } else {
                scene?.updatePieceCrack(id: piece.id, level: next)
            }
        }

        if usesLives {
            lives = max(0, lives - lifeCost)
        }
        if usesLives {
            announceForVoiceOver(String(localized: "Path blocked. \(lives) lives remaining."))
        } else {
            announceForVoiceOver(String(localized: "Path blocked."))
        }

        scene?.performBlocked(pieceId: piece.id, amplified: amplify) { [weak self] in
            guard let self, self.isCurrentSession(generation) else { return }
            self.inputLocked = false
            if self.usesLives && self.lives == 0 {
                self.declareFailure(reason: .outOfLives)
            }
        }
    }

    private func applyKindSideEffectsBeforeFlyOut(piece: ArrowPiece) {
        guard let scene else { return }
        switch piece.kind {
        case .bomb:
            let neighbors = neighborCells(of: piece)
            for cell in neighbors {
                if let ob = scene.board.obstacle(at: cell), ob.kind == .destructible {
                    scene.runExplosion(at: cell)
                    scene.removeObstacle(id: ob.id)
                }
                if let other = scene.board.piece(at: cell), other.id != piece.id {
                    scene.runExplosion(at: cell)
                    var b = scene.board
                    b.removePiece(id: other.id)
                    scene.setBoard(b)
                }
            }
        default:
            break
        }
    }

    @discardableResult
    private func applyKindSideEffectsAfterFlyOut(piece: ArrowPiece) -> Bool {
        guard let scene else { return false }
        switch piece.kind {
        case .chain:
            if let chainedId = piece.chainedPieceId,
               let chained = scene.board.pieces.first(where: { $0.id == chainedId }),
               MoveValidator.canFlyOut(piece: chained, board: scene.board) {
                scheduleChainedMove(pieceId: chained.id)
                return true
            }
        default:
            break
        }
        return false
    }

    private func scheduleChainedMove(pieceId: String) {
        chainedMoveTask?.cancel()
        let generation = sessionGeneration
        chainedMoveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return
            }

            guard let self, self.isCurrentSession(generation) else { return }
            self.chainedMoveTask = nil
            guard let scene = self.scene,
                  let chained = scene.board.pieces.first(where: { $0.id == pieceId }),
                  MoveValidator.canFlyOut(piece: chained, board: scene.board)
            else {
                self.inputLocked = false
                self.checkVictory()
                return
            }
            self.successfulMove(piece: chained)
        }
    }

    private func neighborCells(of piece: ArrowPiece) -> [GridPoint] {
        var out: Set<GridPoint> = []
        let body = Set(piece.cells)
        for cell in piece.cells {
            for dir in Direction.allCases {
                let n = cell.moved(dir)
                if !body.contains(n) { out.insert(n) }
            }
        }
        return Array(out)
    }

    private func checkVictory() {
        guard let scene else { return }
        let pieces = scene.board.pieces

        switch level.goal {
        case .clearAll:
            if pieces.isEmpty { declareVictory() }
        case .clearColorGroup(let group):
            if !pieces.contains(where: { $0.colorGroup == group }) { declareVictory() }
        case .clearWithoutMistakes:
            if pieces.isEmpty && mistakesCount == 0 { declareVictory() }
            else if pieces.isEmpty && mistakesCount > 0 { declareFailure(reason: .goalFailed) }
        case .keysBeforeLocks:
            if pieces.isEmpty { declareVictory() }
        case .freePiece(let id):
            if !pieces.contains(where: { $0.id == id }) { declareVictory() }
        case .clearInSeconds(let target):
            if pieces.isEmpty {
                if elapsedSeconds <= target { declareVictory() }
                else { declareFailure(reason: .goalFailed) }
            }
        case .noHints:
            if pieces.isEmpty {
                if hintsUsed == 0 { declareVictory() }
                else { declareFailure(reason: .goalFailed) }
            }
        }
    }

    private func declareVictory() {
        guard !isCompleted else { return }
        isCompleted = true
        triggerHaptic(.success)
        playSound(.victory)
        scene?.runVictoryBurst()
        recordCompletion()
    }

    private func declareFailure(reason: FailReason) {
        guard !isFailed, !isCompleted else { return }
        isFailed = true
        failReason = reason
        playSound(.failure)
        if canRevive {
            Analytics.log(.reviveOffered)
        }
    }

    #if DEBUG
    func debugDeclareFailure(reason: FailReason) {
        declareFailure(reason: reason)
    }

    func debugDeclareVictory() {
        declareVictory()
    }
    #endif

    // MARK: - economy

    var coinBalance: Int { progressStore.progress.coins }

    var canRevive: Bool { isFailed && failReason == .outOfLives }

    func price(for offer: ResourceOffer) -> Int {
        switch offer {
        case .hint:   return economyConfig.hintCost
        case .undo:   return economyConfig.undoCost
        case .revive: return economyConfig.reviveCost
        }
    }

    func canAfford(_ offer: ResourceOffer) -> Bool {
        coinBalance >= price(for: offer)
    }

    /// Fail-overlay entry point: pays immediately when the balance allows,
    /// otherwise opens the offer sheet.
    func requestRevive() {
        guard canRevive else { return }
        if progressStore.purchaseRevive(config: economyConfig) {
            applyRevive()
        } else {
            resourceOffer = .revive
        }
    }

    /// Coin-slot action of the offer sheet. On success the purchased resource
    /// is applied right away — the interrupted action continues.
    func purchaseOfferedResource() {
        guard let offer = resourceOffer else { return }
        switch offer {
        case .hint:
            guard progressStore.purchaseHint(config: economyConfig) else { return }
            resourceOffer = nil
            consumeHint()
        case .undo:
            guard progressStore.purchaseUndo(config: economyConfig) else { return }
            resourceOffer = nil
            consumeUndo()
        case .revive:
            guard canRevive, progressStore.purchaseRevive(config: economyConfig) else { return }
            resourceOffer = nil
            applyRevive()
        }
        Analytics.log(.offerConverted(context: offer.rawValue, slot: "coins"))
    }

    /// Delivers exactly one non-transferable in-game reward after AdMob has
    /// confirmed the completed view. The interrupted action is retried at once;
    /// if it is no longer applicable, the earned hint/undo remains in inventory.
    @discardableResult
    func applyRewardedOffer(_ offer: ResourceOffer) -> Bool {
        guard resourceOffer == offer else { return false }

        switch offer {
        case .hint:
            progressStore.grantHint()
            resourceOffer = nil
            consumeHint()
        case .undo:
            progressStore.grantUndo()
            resourceOffer = nil
            consumeUndo()
        case .revive:
            guard canRevive else { return false }
            resourceOffer = nil
            applyRevive()
        }

        Analytics.log(.offerConverted(context: offer.rawValue, slot: "rewarded"))
        return true
    }

    /// Keeps timed gameplay paused while an opt-in full-screen ad covers the
    /// board, including the short interval after the earn-reward callback.
    func setRewardedAdPresentationActive(_ isActive: Bool) {
        isRewardedAdPresentationActive = isActive
        if isActive {
            hadCommercialInterruption = true
        }
    }

    func recordCommercialInterruption() {
        hadCommercialInterruption = true
    }

    func dismissResourceOffer() {
        resourceOffer = nil
    }

    /// Continues the interrupted hint action after StoreKit confirms Premium.
    func continueHintAfterPremiumUnlock() {
        updatePremiumAccess(.premium)
        resourceOffer = nil
        consumeHint()
        Analytics.log(.offerConverted(context: ResourceOffer.hint.rawValue, slot: "premium"))
    }

    private func applyRevive() {
        guard canRevive else { return }
        hasUsedRevive = true
        lives = min(totalLives, economyConfig.reviveLives)
        isFailed = false
        failReason = nil
        inputLocked = false
        triggerHaptic(.success)
        Analytics.log(.reviveUsed)
        announceForVoiceOver(String(localized: "Revived. \(lives) lives remaining."))
    }

    private func recordCompletion() {
        let coinsBeforeCompletion = progressStore.progress.coins

        switch mode {
        case .story(let index):
            isFirstStoryCompletion = !progressStore.progress.completedLevels.contains(index)
            progressStore.recordStoryCompletion(
                levelIndex: index, mistakesCount: mistakesCount, level: level
            )
            progressStore.recordStoryBestTime(levelIndex: index, seconds: elapsedSeconds)
            progressStore.checkSkillAchievements(
                mistakesCount: mistakesCount,
                hintsUsed: hintsUsed,
                elapsedSeconds: elapsedSeconds,
                maxCombo: maxCombo,
                levelIndex: index
            )
            // Quest: perfect clears and hintless
            if level.stars(for: mistakesCount) == 3 {
                progressStore.updateQuestProgress(type: .perfectClears, increment: 1)
            }
            if hintsUsed == 0 {
                progressStore.updateQuestProgress(type: .hintlessClears, increment: 1)
            }
            showPendingAchievementBannerIfNeeded()

        case .daily(let date):
            isFirstStoryCompletion = false
            progressStore.recordDailyCompletion(
                date: date, mistakesCount: mistakesCount, level: level,
                config: economyConfig
            )
            showPendingAchievementBannerIfNeeded()

        case .weekly(let week):
            isFirstStoryCompletion = false
            progressStore.markWeeklyCompleted(week: week)
            showPendingAchievementBannerIfNeeded()

        case .zen(let date, _):
            isFirstStoryCompletion = false
            progressStore.recordZenCompletion(date: date)

        case .master(let index):
            isFirstStoryCompletion = false
            progressStore.recordMasterCompletion(
                levelIndex: index, modifier: gameMode, config: economyConfig
            )
            showPendingAchievementBannerIfNeeded()

        case .generated:
            isFirstStoryCompletion = false
            break
        }

        completionCoinReward = max(0, progressStore.progress.coins - coinsBeforeCompletion)
    }

    private func showPendingAchievementBannerIfNeeded() {
        let newly = progressStore.consumeNewAchievements()
        if let first = newly.first {
            pendingAchievementBanner = first
        }
    }

    func dismissAchievementBanner() {
        pendingAchievementBanner = nil
    }

    private func announceForVoiceOver(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    var earnedStars: Int { level.stars(for: mistakesCount) }

    // MARK: - combo / feedback

    #if DEBUG
    /// Freezes an authentic combo HUD state for deterministic App Store
    /// captures. No production call site can compile this helper.
    func prepareForScreenshot(combo: Int, movesMade: Int) {
        let value = max(2, combo)
        self.combo = value
        self.maxCombo = value
        self.movesMade = max(0, movesMade)
        self.showComboBurst = true
        self.comboCallout = comboCalloutText(for: value)
        comboDismissTask?.cancel()
        comboDismissTask = nil
    }
    #endif

    private func triggerComboBurst() {
        showComboBurst = true
        comboCallout = comboCalloutText(for: combo)
        comboDismissTask?.cancel()
        let generation = sessionGeneration
        comboDismissTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(750))
            } catch {
                return
            }

            guard let self, self.isCurrentSession(generation) else { return }
            self.comboDismissTask = nil
            self.showComboBurst = false
            self.comboCallout = nil
        }
    }

    private func isCurrentSession(_ generation: UInt) -> Bool {
        isSessionActive && sessionGeneration == generation
    }

    private func invalidatePendingWork() {
        sessionGeneration &+= 1
        chainedMoveTask?.cancel()
        chainedMoveTask = nil
        comboDismissTask?.cancel()
        comboDismissTask = nil
    }

    private func comboCalloutText(for combo: Int) -> String? {
        switch combo {
        case 3: return String(localized: "Chain!")
        case 4: return String(localized: "Chain Clear!")
        case 5: return String(localized: "Sweep!")
        case 6...9: return String(localized: "On Fire!")
        case 10...: return String(localized: "Unstoppable!")
        default: return nil
        }
    }

    private enum HapticKind { case light, success, warning }

    private func playSound(_ effect: GameSoundEffect) {
        guard settingsStore.settings.soundEnabled else { return }
        soundPlayer.play(effect)
    }

    private func triggerHaptic(_ kind: HapticKind) {
        guard settingsStore.settings.hapticsEnabled else { return }
        switch kind {
        case .light:
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare(); g.impactOccurred()
        case .success:
            let g = UINotificationFeedbackGenerator()
            g.prepare(); g.notificationOccurred(.success)
        case .warning:
            let g = UINotificationFeedbackGenerator()
            g.prepare(); g.notificationOccurred(.warning)
        }
    }
}
