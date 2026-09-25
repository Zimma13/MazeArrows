//
//  GameCenterStoreTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Testing
import UIKit
@testable import MazeArrows

private struct SubmittedLeaderboardScore: Equatable {
    let score: Int
    let leaderboardID: String
}

@MainActor
private final class FakeGameCenterClient: GameCenterClient {
    var authenticatedPlayer: GameCenterPlayerProfile?
    private(set) var handlerInstallCount = 0
    private(set) var submittedScores: [SubmittedLeaderboardScore] = []
    private(set) var submittedAchievementBatches: [[String]] = []
    private(set) var presentedDestinations: [GameCenterDestination] = []
    var queuedSubmissionErrors: [NSError] = []
    var queuedAchievementErrors: [NSError] = []
    private var handler: ((UIViewController?, (any Error)?) -> Void)?

    func setAuthenticationHandler(
        _ handler: @escaping (UIViewController?, (any Error)?) -> Void
    ) {
        handlerInstallCount += 1
        self.handler = handler
    }

    func respond(
        viewController: UIViewController? = nil,
        error: (any Error)? = nil
    ) {
        handler?(viewController, error)
    }

    func submitScore(_ score: Int, to leaderboardID: String) async throws {
        submittedScores.append(SubmittedLeaderboardScore(
            score: score,
            leaderboardID: leaderboardID
        ))
        if !queuedSubmissionErrors.isEmpty {
            throw queuedSubmissionErrors.removeFirst()
        }
    }

    func submitAchievements(_ achievementIDs: [String]) async throws {
        submittedAchievementBatches.append(achievementIDs)
        if !queuedAchievementErrors.isEmpty {
            throw queuedAchievementErrors.removeFirst()
        }
    }

    func presentGameCenter(_ destination: GameCenterDestination) {
        presentedDestinations.append(destination)
    }
}

@MainActor
struct GameCenterStoreTests {
    private let profile = GameCenterPlayerProfile(
        gamePlayerID: "G:12345",
        displayName: "Maze Player",
        alias: "Player",
        isUnderage: false,
        isMultiplayerGamingRestricted: false,
        isPersonalizedCommunicationRestricted: false
    )

    private func makeDefaults() -> UserDefaults {
        let suiteName = "MazeArrows.GameCenterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeProgress(
        completedLevels: Set<Int> = [],
        masterClears: [Int: Set<GameMode>] = [:],
        dailyStreak: Int = 0,
        bestDailyStreak: Int = 0
    ) -> PlayerProgress {
        var progress = PlayerProgress.initial
        progress.completedLevels = completedLevels
        progress.masterClears = masterClears
        progress.dailyStreak = dailyStreak
        progress.bestDailyStreak = bestDailyStreak
        return progress
    }

    @Test func startInstallsAuthenticationHandlerOnlyOnce() {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client)

        store.start()
        store.start()

        #expect(client.handlerInstallCount == 1)
        #expect(store.connectionState == .authenticating)
    }

    @Test func systemControllerIsExposedUntilAuthenticationCompletes() throws {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client)
        let controller = UIViewController()

        store.start()
        client.respond(viewController: controller)

        let request = try #require(store.authenticationRequest)
        #expect(request.viewController === controller)
        #expect(store.connectionState == .awaitingPlayerAction)

        client.authenticatedPlayer = profile
        client.respond()

        #expect(store.authenticationRequest == nil)
        #expect(store.connectionState == .authenticated)
        #expect(store.player == profile)
        #expect(store.isAuthenticated)
    }

    @Test func failureLeavesGameplayAvailableAndCanBeRetried() throws {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client)

        store.start()
        client.respond(error: NSError(domain: "GKErrorDomain", code: 6))

        #expect(store.connectionState == .unavailable)
        #expect(store.player == nil)
        #expect(store.lastFailure == GameCenterAuthenticationFailure(
            error: NSError(domain: "GKErrorDomain", code: 6)
        ))

        store.retryAuthentication()

        #expect(client.handlerInstallCount == 2)
        #expect(store.connectionState == .authenticating)
        #expect(store.lastFailure == nil)
    }

    @Test func activeRefreshDetectsPlayerSignOut() {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client)
        client.authenticatedPlayer = profile

        store.start()
        client.respond()
        #expect(store.isAuthenticated)

        client.authenticatedPlayer = nil
        store.refreshPlayerState()

        #expect(store.connectionState == .unavailable)
        #expect(store.player == nil)
        #expect(!store.isAuthenticated)
    }

    @Test func gameCenterPresentationRequiresAuthentication() {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client)

        store.presentGameCenter(.dashboard)

        #expect(client.presentedDestinations.isEmpty)
    }

    @Test func authenticatedPlayerCanOpenEveryGameCenterDestination() {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client)
        client.authenticatedPlayer = profile
        store.start()
        client.respond()

        for destination in GameCenterDestination.allCases {
            store.presentGameCenter(destination)
        }

        #expect(client.presentedDestinations == GameCenterDestination.allCases)
    }

    @Test func snapshotContainsOnlyStableHighScores() {
        let progress = makeProgress(
            completedLevels: [1, 2, 5],
            masterClears: [1: [.hard, .timed], 5: [.challenge]],
            dailyStreak: 2,
            bestDailyStreak: 8
        )

        let snapshot = GameCenterLeaderboardSnapshot(progress: progress)

        #expect(snapshot.campaignLevelsCompleted == 3)
        #expect(snapshot.masterCrowns == 3)
        #expect(snapshot.longestDailyStreak == 8)
    }

    @Test func queuedScoresCoalesceAndUploadAfterAuthentication() async {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client, defaults: makeDefaults())

        store.synchronizeLeaderboards(with: GameCenterLeaderboardSnapshot(
            progress: makeProgress(completedLevels: [1, 2])
        ))
        store.synchronizeLeaderboards(with: GameCenterLeaderboardSnapshot(
            progress: makeProgress(completedLevels: [1, 2, 3, 4])
        ))

        #expect(store.pendingLeaderboardSubmissionCount == 1)
        #expect(client.submittedScores.isEmpty)

        store.start()
        client.authenticatedPlayer = profile
        client.respond()
        await store.waitForLeaderboardSync()

        #expect(client.submittedScores == [SubmittedLeaderboardScore(
            score: 4,
            leaderboardID: GameCenterLeaderboardID.campaignLevelsCompleted.rawValue
        )])
        #expect(store.pendingLeaderboardSubmissionCount == 0)
    }

    @Test func failedUploadStaysQueuedAndRetriesWithoutLosingScores() async {
        let client = FakeGameCenterClient()
        client.queuedSubmissionErrors = [NSError(domain: "GKErrorDomain", code: 3)]
        let store = GameCenterStore(client: client, defaults: makeDefaults())
        let progress = makeProgress(
            completedLevels: [1, 2, 3],
            masterClears: [1: [.hard]],
            dailyStreak: 5,
            bestDailyStreak: 5
        )

        store.synchronizeLeaderboards(with: GameCenterLeaderboardSnapshot(progress: progress))
        store.start()
        client.authenticatedPlayer = profile
        client.respond()
        await store.waitForLeaderboardSync()

        #expect(store.pendingLeaderboardSubmissionCount == 3)

        store.retryPendingLeaderboardSubmissions()
        await store.waitForLeaderboardSync()

        #expect(store.pendingLeaderboardSubmissionCount == 0)
        #expect(client.submittedScores.count == 4)
        #expect(client.submittedScores[0] == client.submittedScores[1])
    }

    @Test func persistedCheckpointAvoidsRelaunchDuplicatesForSamePlayer() async {
        let defaults = makeDefaults()
        let firstClient = FakeGameCenterClient()
        let firstStore = GameCenterStore(client: firstClient, defaults: defaults)
        let snapshot = GameCenterLeaderboardSnapshot(
            progress: makeProgress(completedLevels: [1, 2, 3])
        )

        firstStore.synchronizeLeaderboards(with: snapshot)
        firstStore.start()
        firstClient.authenticatedPlayer = profile
        firstClient.respond()
        await firstStore.waitForLeaderboardSync()
        #expect(firstClient.submittedScores.count == 1)

        let relaunchedClient = FakeGameCenterClient()
        let relaunchedStore = GameCenterStore(client: relaunchedClient, defaults: defaults)
        relaunchedStore.synchronizeLeaderboards(with: snapshot)
        relaunchedStore.start()
        relaunchedClient.authenticatedPlayer = profile
        relaunchedClient.respond()
        await relaunchedStore.waitForLeaderboardSync()

        #expect(relaunchedClient.submittedScores.isEmpty)
        #expect(relaunchedStore.pendingLeaderboardSubmissionCount == 0)
    }

    @Test func sameLocalScoresAreSubmittedForAChangedPlayer() async {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client, defaults: makeDefaults())
        let snapshot = GameCenterLeaderboardSnapshot(
            progress: makeProgress(completedLevels: [1, 2])
        )

        store.synchronizeLeaderboards(with: snapshot)
        store.start()
        client.authenticatedPlayer = profile
        client.respond()
        await store.waitForLeaderboardSync()

        client.authenticatedPlayer = GameCenterPlayerProfile(
            gamePlayerID: "G:67890",
            displayName: "Second Player",
            alias: "Second",
            isUnderage: false,
            isMultiplayerGamingRestricted: false,
            isPersonalizedCommunicationRestricted: false
        )
        store.refreshPlayerState()
        await store.waitForLeaderboardSync()

        #expect(client.submittedScores.count == 2)
        #expect(client.submittedScores[0] == client.submittedScores[1])
        #expect(store.pendingLeaderboardSubmissionCount == 0)
    }

    @Test func achievementConfigurationMatchesEveryLocalAchievement() {
        #expect(GameCenterAchievementID.allCases.count == AchievementID.allCases.count)
        #expect(Set(GameCenterAchievementID.allCases.map(\.localID)) == Set(AchievementID.allCases))
        #expect(Set(GameCenterAchievementID.allCases.map(\.rawValue)).count == 15)
        #expect(GameCenterAchievementID.allCases.allSatisfy {
            (1...100).contains($0.points) && !$0.isHidden && !$0.isRepeatable
        })
        #expect(GameCenterAchievementID.totalPoints == 600)
        #expect(GameCenterAchievementID.totalPoints <= 1_000)
    }

    @Test func everyAchievementHasUniqueBundledArtwork() {
        let imageAssetNames = Achievement.all.map(\.imageAssetName)

        #expect(imageAssetNames.count == AchievementID.allCases.count)
        #expect(Set(imageAssetNames).count == imageAssetNames.count)
        for imageAssetName in imageAssetNames {
            #expect(UIImage(named: imageAssetName) != nil)
        }
    }

    @Test func earnedAchievementsUploadAsOneBatchAfterAuthentication() async {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client, defaults: makeDefaults())
        let snapshot = GameCenterAchievementSnapshot(
            earnedAchievements: [.firstClear, .perfectClear, .streak3]
        )

        store.synchronizeAchievements(with: snapshot)
        #expect(store.pendingAchievementSubmissionCount == 3)
        #expect(client.submittedAchievementBatches.isEmpty)

        store.start()
        client.authenticatedPlayer = profile
        client.respond()
        await store.waitForAchievementSync()

        #expect(client.submittedAchievementBatches == [[
            GameCenterAchievementID.firstClear.rawValue,
            GameCenterAchievementID.perfectClear.rawValue,
            GameCenterAchievementID.streak3.rawValue
        ]])
        #expect(store.pendingAchievementSubmissionCount == 0)
    }

    @Test func failedAchievementBatchPersistsAndRetries() async {
        let defaults = makeDefaults()
        let firstClient = FakeGameCenterClient()
        firstClient.queuedAchievementErrors = [
            NSError(domain: "GKErrorDomain", code: 3)
        ]
        let firstStore = GameCenterStore(client: firstClient, defaults: defaults)
        let snapshot = GameCenterAchievementSnapshot(
            earnedAchievements: [.chapter1Complete, .hintlessWin]
        )

        firstStore.synchronizeAchievements(with: snapshot)
        firstStore.start()
        firstClient.authenticatedPlayer = profile
        firstClient.respond()
        await firstStore.waitForAchievementSync()
        #expect(firstStore.pendingAchievementSubmissionCount == 2)

        let relaunchedClient = FakeGameCenterClient()
        let relaunchedStore = GameCenterStore(client: relaunchedClient, defaults: defaults)
        relaunchedStore.synchronizeAchievements(with: snapshot)
        relaunchedStore.start()
        relaunchedClient.authenticatedPlayer = profile
        relaunchedClient.respond()
        await relaunchedStore.waitForAchievementSync()

        #expect(relaunchedClient.submittedAchievementBatches.count == 1)
        #expect(relaunchedStore.pendingAchievementSubmissionCount == 0)
    }

    @Test func submittedAchievementsAreNotDuplicatedOnRelaunch() async {
        let defaults = makeDefaults()
        let snapshot = GameCenterAchievementSnapshot(
            earnedAchievements: [.questComplete, .coinCollector]
        )
        let firstClient = FakeGameCenterClient()
        let firstStore = GameCenterStore(client: firstClient, defaults: defaults)

        firstStore.synchronizeAchievements(with: snapshot)
        firstStore.start()
        firstClient.authenticatedPlayer = profile
        firstClient.respond()
        await firstStore.waitForAchievementSync()

        let relaunchedClient = FakeGameCenterClient()
        let relaunchedStore = GameCenterStore(client: relaunchedClient, defaults: defaults)
        relaunchedStore.synchronizeAchievements(with: snapshot)
        relaunchedStore.start()
        relaunchedClient.authenticatedPlayer = profile
        relaunchedClient.respond()
        await relaunchedStore.waitForAchievementSync()

        #expect(firstClient.submittedAchievementBatches.count == 1)
        #expect(relaunchedClient.submittedAchievementBatches.isEmpty)
        #expect(relaunchedStore.pendingAchievementSubmissionCount == 0)
    }

    @Test func achievementsResynchronizeForChangedPlayer() async {
        let client = FakeGameCenterClient()
        let store = GameCenterStore(client: client, defaults: makeDefaults())
        store.synchronizeAchievements(with: GameCenterAchievementSnapshot(
            earnedAchievements: [.weeklyChampion]
        ))

        store.start()
        client.authenticatedPlayer = profile
        client.respond()
        await store.waitForAchievementSync()

        client.authenticatedPlayer = GameCenterPlayerProfile(
            gamePlayerID: "G:67890",
            displayName: "Second Player",
            alias: "Second",
            isUnderage: false,
            isMultiplayerGamingRestricted: false,
            isPersonalizedCommunicationRestricted: false
        )
        store.refreshPlayerState()
        await store.waitForAchievementSync()

        #expect(client.submittedAchievementBatches.count == 2)
        #expect(client.submittedAchievementBatches[0] == client.submittedAchievementBatches[1])
        #expect(store.pendingAchievementSubmissionCount == 0)
    }
}
