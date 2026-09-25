//
//  GameCenterStore.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Initializes Game Center once at launch and exposes a small, testable
//  player snapshot to the rest of the app. Gameplay never depends on a
//  successful sign-in.
//

import Foundation
import GameKit
import Observation
import UIKit

struct GameCenterPlayerProfile: Equatable, Sendable {
    let gamePlayerID: String
    let displayName: String
    let alias: String
    let isUnderage: Bool
    let isMultiplayerGamingRestricted: Bool
    let isPersonalizedCommunicationRestricted: Bool
}

enum GameCenterConnectionState: Equatable, Sendable {
    case idle
    case authenticating
    case awaitingPlayerAction
    case authenticated
    case unavailable
}

enum GameCenterDestination: CaseIterable, Equatable, Sendable {
    case dashboard
    case achievements
    case leaderboards
}

struct GameCenterAuthenticationFailure: Equatable, Sendable {
    let domain: String
    let code: Int

    init(error: any Error) {
        let error = error as NSError
        domain = error.domain
        code = error.code
    }

    var analyticsReason: String {
        "\(domain):\(code)"
    }
}

@MainActor
struct GameCenterAuthenticationRequest: Identifiable {
    let id = UUID()
    let viewController: UIViewController
}

@MainActor
protocol GameCenterClient: AnyObject {
    var authenticatedPlayer: GameCenterPlayerProfile? { get }

    func setAuthenticationHandler(
        _ handler: @escaping (UIViewController?, (any Error)?) -> Void
    )

    func submitScore(_ score: Int, to leaderboardID: String) async throws
    func submitAchievements(_ achievementIDs: [String]) async throws
    func presentGameCenter(_ destination: GameCenterDestination)
}

@MainActor
private final class LiveGameCenterClient: GameCenterClient {
    private let localPlayer = GKLocalPlayer.local

    var authenticatedPlayer: GameCenterPlayerProfile? {
        guard localPlayer.isAuthenticated else { return nil }
        return GameCenterPlayerProfile(
            gamePlayerID: localPlayer.gamePlayerID,
            displayName: localPlayer.displayName,
            alias: localPlayer.alias,
            isUnderage: localPlayer.isUnderage,
            isMultiplayerGamingRestricted: localPlayer.isMultiplayerGamingRestricted,
            isPersonalizedCommunicationRestricted:
                localPlayer.isPersonalizedCommunicationRestricted
        )
    }

    func setAuthenticationHandler(
        _ handler: @escaping (UIViewController?, (any Error)?) -> Void
    ) {
        localPlayer.authenticateHandler = handler
    }

    func submitScore(_ score: Int, to leaderboardID: String) async throws {
        try await GKLeaderboard.submitScore(
            score,
            context: 0,
            player: localPlayer,
            leaderboardIDs: [leaderboardID]
        )
    }

    func submitAchievements(_ achievementIDs: [String]) async throws {
        let achievements = achievementIDs.map { identifier in
            let achievement = GKAchievement(identifier: identifier, player: localPlayer)
            achievement.percentComplete = 100
            // Arrow Maze already presents its own themed completion banner.
            achievement.showsCompletionBanner = false
            return achievement
        }
        try await GKAchievement.report(achievements)
    }

    func presentGameCenter(_ destination: GameCenterDestination) {
        let accessPoint = GKAccessPoint.shared
        guard !accessPoint.isPresentingGameCenter else { return }

        let state: GKGameCenterViewControllerState = switch destination {
        case .dashboard:
            .dashboard
        case .achievements:
            .achievements
        case .leaderboards:
            .leaderboards
        }
        accessPoint.trigger(state: state) {}
    }
}

private struct GameCenterLeaderboardSyncState: Codable {
    var desiredScores: [String: Int] = [:]
    var submittedScoresByPlayer: [String: [String: Int]] = [:]

    func sanitized() -> Self {
        let validIDs = Set(GameCenterLeaderboardID.allCases.map(\.rawValue))
        var result = Self()

        result.desiredScores = desiredScores.filter {
            validIDs.contains($0.key) && $0.value > 0
        }
        result.submittedScoresByPlayer = submittedScoresByPlayer.reduce(into: [:]) {
            players, entry in
            let scores = entry.value.filter {
                validIDs.contains($0.key) && $0.value > 0
            }
            if !entry.key.isEmpty, !scores.isEmpty {
                players[entry.key] = scores
            }
        }
        return result
    }
}

private struct GameCenterAchievementSyncState: Codable {
    var desiredAchievementIDs: Set<String> = []
    var submittedAchievementIDsByPlayer: [String: Set<String>] = [:]

    func sanitized() -> Self {
        let validIDs = Set(GameCenterAchievementID.allCases.map(\.rawValue))
        var result = Self()

        result.desiredAchievementIDs = desiredAchievementIDs.intersection(validIDs)
        result.submittedAchievementIDsByPlayer = submittedAchievementIDsByPlayer
            .reduce(into: [:]) { players, entry in
                let identifiers = entry.value.intersection(validIDs)
                if !entry.key.isEmpty, !identifiers.isEmpty {
                    players[entry.key] = identifiers
                }
            }
        return result
    }
}

@MainActor
@Observable
final class GameCenterStore {
    private(set) var connectionState: GameCenterConnectionState = .idle
    private(set) var player: GameCenterPlayerProfile?
    private(set) var authenticationRequest: GameCenterAuthenticationRequest?
    private(set) var lastFailure: GameCenterAuthenticationFailure?
    private(set) var pendingLeaderboardSubmissionCount = 0
    private(set) var pendingAchievementSubmissionCount = 0

    @ObservationIgnored private let client: any GameCenterClient
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var leaderboardSyncState: GameCenterLeaderboardSyncState
    @ObservationIgnored private var leaderboardSyncTask: Task<Void, Never>?
    @ObservationIgnored private var achievementSyncState: GameCenterAchievementSyncState
    @ObservationIgnored private var achievementSyncTask: Task<Void, Never>?

    private static let leaderboardSyncDefaultsKey =
        "MazeArrows.GameCenterLeaderboardSync.v1"
    private static let achievementSyncDefaultsKey =
        "MazeArrows.GameCenterAchievementSync.v1"

    init(
        client: (any GameCenterClient)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.client = client ?? LiveGameCenterClient()
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.leaderboardSyncDefaultsKey),
           let decoded = try? JSONDecoder().decode(
               GameCenterLeaderboardSyncState.self,
               from: data
           ) {
            leaderboardSyncState = decoded.sanitized()
        } else {
            leaderboardSyncState = GameCenterLeaderboardSyncState()
        }

        if let data = defaults.data(forKey: Self.achievementSyncDefaultsKey),
           let decoded = try? JSONDecoder().decode(
               GameCenterAchievementSyncState.self,
               from: data
           ) {
            achievementSyncState = decoded.sanitized()
        } else {
            achievementSyncState = GameCenterAchievementSyncState()
        }

        refreshPendingLeaderboardSubmissionCount()
        refreshPendingAchievementSubmissionCount()
    }

    var isAuthenticated: Bool {
        connectionState == .authenticated && player != nil
    }

    /// Opens Apple's native Game Center interface at a specific destination.
    /// The action is ignored until GameKit confirms an authenticated player.
    func presentGameCenter(_ destination: GameCenterDestination) {
        guard isAuthenticated else { return }
        client.presentGameCenter(destination)
    }

    /// Records local high-water marks and starts a best-effort upload. The
    /// desired scores stay persisted until every Game Center player used on
    /// this device has received them.
    func synchronizeLeaderboards(with snapshot: GameCenterLeaderboardSnapshot) {
        var didChange = false

        for (leaderboard, score) in snapshot.scores where score > 0 {
            let identifier = leaderboard.rawValue
            let previous = leaderboardSyncState.desiredScores[identifier] ?? 0
            guard score > previous else { continue }
            leaderboardSyncState.desiredScores[identifier] = score
            didChange = true
        }

        if didChange {
            persistLeaderboardSyncState()
        }
        refreshPendingLeaderboardSubmissionCount()
        scheduleLeaderboardSync()
    }

    /// Queues every locally earned achievement at 100%. Previously earned
    /// achievements are intentionally included so a new Game Center account
    /// can be brought up to date after authentication.
    func synchronizeAchievements(with snapshot: GameCenterAchievementSnapshot) {
        let identifiers = Set(snapshot.earned.map(\.rawValue))
        let previousCount = achievementSyncState.desiredAchievementIDs.count
        achievementSyncState.desiredAchievementIDs.formUnion(identifiers)

        if achievementSyncState.desiredAchievementIDs.count != previousCount {
            persistAchievementSyncState()
        }
        refreshPendingAchievementSubmissionCount()
        scheduleAchievementSync()
    }

    /// Called when the app becomes active or the player explicitly retries.
    /// A network/GameKit failure remains queued and never blocks gameplay.
    func retryPendingLeaderboardSubmissions() {
        scheduleLeaderboardSync()
    }

    func retryPendingGameCenterSubmissions() {
        scheduleLeaderboardSync()
        scheduleAchievementSync()
    }

    /// Apple recommends installing the handler when the game launches.
    /// GameKit may invoke it more than once during one authentication flow.
    func start() {
        guard !hasStarted else {
            refreshPlayerState()
            return
        }

        hasStarted = true
        installAuthenticationHandler()
    }

    /// Reinstalls the handler only after an explicit player action in Settings.
    func retryAuthentication() {
        guard !isAuthenticated else {
            refreshPlayerState()
            return
        }
        installAuthenticationHandler()
    }

    /// Reconciles sign-out or account changes after the app becomes active.
    func refreshPlayerState() {
        guard hasStarted else { return }

        if let player = client.authenticatedPlayer {
            becomeAuthenticated(player)
            return
        }

        player = nil
        refreshPendingLeaderboardSubmissionCount()
        refreshPendingAchievementSubmissionCount()
        if authenticationRequest != nil {
            connectionState = .awaitingPlayerAction
        } else if hasStarted, connectionState != .authenticating {
            connectionState = .unavailable
        }
    }

    func authenticationPresentationWasDismissed(id: UUID) {
        guard authenticationRequest?.id == id else { return }
        authenticationRequest = nil
        refreshPlayerState()
        if player == nil {
            connectionState = .unavailable
        }
    }

    private func installAuthenticationHandler() {
        authenticationRequest = nil
        player = nil
        lastFailure = nil
        connectionState = .authenticating
        Analytics.log(.gameCenterAuthenticationStarted)

        client.setAuthenticationHandler { [weak self] viewController, error in
            self?.handleAuthenticationCallback(
                viewController: viewController,
                error: error
            )
        }
    }

    private func handleAuthenticationCallback(
        viewController: UIViewController?,
        error: (any Error)?
    ) {
        if let player = client.authenticatedPlayer {
            authenticationRequest = nil
            becomeAuthenticated(player)
            return
        }

        if let viewController {
            lastFailure = nil
            authenticationRequest = GameCenterAuthenticationRequest(
                viewController: viewController
            )
            connectionState = .awaitingPlayerAction
            return
        }

        authenticationRequest = nil
        player = nil
        connectionState = .unavailable

        if let error {
            let failure = GameCenterAuthenticationFailure(error: error)
            lastFailure = failure
            Analytics.log(.gameCenterAuthenticationFailed(
                reason: failure.analyticsReason
            ))
        } else {
            lastFailure = nil
            Analytics.log(.gameCenterAuthenticationFailed(
                reason: "player_not_authenticated"
            ))
        }
    }

    private func becomeAuthenticated(_ player: GameCenterPlayerProfile) {
        let shouldLog = self.player?.gamePlayerID != player.gamePlayerID
            || connectionState != .authenticated

        authenticationRequest = nil
        lastFailure = nil
        self.player = player
        connectionState = .authenticated
        refreshPendingLeaderboardSubmissionCount()
        refreshPendingAchievementSubmissionCount()
        scheduleLeaderboardSync()
        scheduleAchievementSync()

        if shouldLog {
            Analytics.log(.gameCenterAuthenticated(
                isUnderage: player.isUnderage,
                isMultiplayerRestricted: player.isMultiplayerGamingRestricted,
                isCommunicationRestricted:
                    player.isPersonalizedCommunicationRestricted
            ))
        }
    }

    private func scheduleLeaderboardSync() {
        guard isAuthenticated,
              pendingLeaderboardSubmissionCount > 0,
              leaderboardSyncTask == nil
        else { return }

        leaderboardSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.drainLeaderboardQueue()
            self.leaderboardSyncTask = nil
            self.refreshPendingLeaderboardSubmissionCount()
        }
    }

    private func drainLeaderboardQueue() async {
        while let player, isAuthenticated {
            let playerID = player.gamePlayerID
            guard let submission = pendingLeaderboardSubmissions(for: playerID).first else {
                return
            }

            do {
                try await client.submitScore(
                    submission.score,
                    to: submission.leaderboard.rawValue
                )
            } catch {
                let error = error as NSError
                Analytics.log(.gameCenterLeaderboardSubmissionFailed(
                    identifier: submission.leaderboard.rawValue,
                    reason: "\(error.domain):\(error.code)"
                ))
                return
            }

            // Authentication can change while GameKit is awaiting the server.
            // In that case, leave the item pending; an idempotent retry is safer
            // than attributing a successful upload to the wrong player.
            guard self.player?.gamePlayerID == playerID, isAuthenticated else {
                continue
            }

            var submitted = leaderboardSyncState.submittedScoresByPlayer[playerID] ?? [:]
            submitted[submission.leaderboard.rawValue] = max(
                submitted[submission.leaderboard.rawValue] ?? 0,
                submission.score
            )
            leaderboardSyncState.submittedScoresByPlayer[playerID] = submitted
            persistLeaderboardSyncState()
            refreshPendingLeaderboardSubmissionCount()
            Analytics.log(.gameCenterLeaderboardSubmitted(
                identifier: submission.leaderboard.rawValue,
                score: submission.score
            ))
        }
    }

    private func scheduleAchievementSync() {
        guard isAuthenticated,
              pendingAchievementSubmissionCount > 0,
              achievementSyncTask == nil
        else { return }

        achievementSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.drainAchievementQueue()
            self.achievementSyncTask = nil
            self.refreshPendingAchievementSubmissionCount()
        }
    }

    private func drainAchievementQueue() async {
        while let player, isAuthenticated {
            let playerID = player.gamePlayerID
            let pending = pendingAchievements(for: playerID)
            guard !pending.isEmpty else { return }
            let identifiers = pending.map(\.rawValue)

            do {
                try await client.submitAchievements(identifiers)
            } catch {
                let error = error as NSError
                Analytics.log(.gameCenterAchievementSubmissionFailed(
                    count: identifiers.count,
                    reason: "\(error.domain):\(error.code)"
                ))
                return
            }

            // Authentication can change while the report is in flight. Leave
            // the checkpoint untouched and make a harmless idempotent retry.
            guard self.player?.gamePlayerID == playerID, isAuthenticated else {
                continue
            }

            var submitted = achievementSyncState
                .submittedAchievementIDsByPlayer[playerID] ?? []
            submitted.formUnion(identifiers)
            achievementSyncState.submittedAchievementIDsByPlayer[playerID] = submitted
            persistAchievementSyncState()
            refreshPendingAchievementSubmissionCount()
            Analytics.log(.gameCenterAchievementsSubmitted(count: identifiers.count))
        }
    }

    private func pendingAchievements(
        for playerID: String
    ) -> [GameCenterAchievementID] {
        let submitted = achievementSyncState
            .submittedAchievementIDsByPlayer[playerID] ?? []
        return GameCenterAchievementID.allCases.filter {
            achievementSyncState.desiredAchievementIDs.contains($0.rawValue)
                && !submitted.contains($0.rawValue)
        }
    }

    private func pendingLeaderboardSubmissions(
        for playerID: String
    ) -> [(leaderboard: GameCenterLeaderboardID, score: Int)] {
        let submitted = leaderboardSyncState.submittedScoresByPlayer[playerID] ?? [:]

        return GameCenterLeaderboardID.allCases.compactMap { leaderboard in
            let identifier = leaderboard.rawValue
            let desiredScore = leaderboardSyncState.desiredScores[identifier] ?? 0
            guard desiredScore > (submitted[identifier] ?? 0) else { return nil }
            return (leaderboard, desiredScore)
        }
    }

    private func refreshPendingLeaderboardSubmissionCount() {
        if let playerID = player?.gamePlayerID {
            pendingLeaderboardSubmissionCount = pendingLeaderboardSubmissions(
                for: playerID
            ).count
        } else {
            pendingLeaderboardSubmissionCount = leaderboardSyncState.desiredScores
                .values
                .filter { $0 > 0 }
                .count
        }
    }

    private func refreshPendingAchievementSubmissionCount() {
        if let playerID = player?.gamePlayerID {
            pendingAchievementSubmissionCount = pendingAchievements(for: playerID).count
        } else {
            pendingAchievementSubmissionCount = achievementSyncState
                .desiredAchievementIDs
                .count
        }
    }

    private func persistLeaderboardSyncState() {
        guard let data = try? JSONEncoder().encode(leaderboardSyncState) else { return }
        defaults.set(data, forKey: Self.leaderboardSyncDefaultsKey)
    }

    private func persistAchievementSyncState() {
        guard let data = try? JSONEncoder().encode(achievementSyncState) else { return }
        defaults.set(data, forKey: Self.achievementSyncDefaultsKey)
    }

    /// Test seam for waiting on the currently scheduled best-effort upload.
    func waitForLeaderboardSync() async {
        await leaderboardSyncTask?.value
    }

    func waitForAchievementSync() async {
        await achievementSyncTask?.value
    }
}
