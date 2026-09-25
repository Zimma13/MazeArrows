//
//  AdMobConfigurationTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Testing
@testable import MazeArrows

struct AdMobConfigurationTests {
    @Test func productionIdentifiersHaveExpectedFormatsAndAreUnique() {
        let configuration = AdMobConfiguration.production
        let adUnits = [
            configuration.interstitialLevelComplete,
            configuration.rewardedHint,
            configuration.rewardedUndo,
            configuration.rewardedRevive,
            configuration.rewardedPhotoMaze
        ]

        #expect(configuration.appID.hasPrefix("ca-app-pub-"))
        #expect(configuration.appID.contains("~"))
        #expect(!configuration.appID.contains("/"))
        #expect(adUnits.allSatisfy { $0.hasPrefix("ca-app-pub-") })
        #expect(adUnits.allSatisfy { $0.contains("/") && !$0.contains("~") })
        #expect(Set(adUnits).count == adUnits.count)
    }

    @Test func debugBuildAlwaysSelectsGoogleDemoInventory() {
        #if DEBUG
        #expect(AdMobConfiguration.current == .test)
        #expect(
            AdMobConfiguration.current.interstitialLevelComplete
                == "ca-app-pub-3940256099942544/4411468910"
        )
        #expect(
            AdMobConfiguration.current.rewardedHint
                == "ca-app-pub-3940256099942544/1712485313"
        )
        #endif
    }

    @Test func rewardedPlacementsMapToTheirDedicatedProductionUnits() {
        let configuration = AdMobConfiguration.production

        #expect(RewardedAdPlacement.hint.adUnitID(in: configuration) == configuration.rewardedHint)
        #expect(RewardedAdPlacement.undo.adUnitID(in: configuration) == configuration.rewardedUndo)
        #expect(RewardedAdPlacement.revive.adUnitID(in: configuration) == configuration.rewardedRevive)
        #expect(
            RewardedAdPlacement.photoMaze.adUnitID(in: configuration)
                == configuration.rewardedPhotoMaze
        )
        #expect(RewardedAdPlacement.resourceOffers == [.hint, .undo, .revive])
    }

    @Test(
        "Pending Game Center states keep ad bootstrap fail-closed",
        arguments: [
            GameCenterConnectionState.idle,
            .authenticating,
            .awaitingPlayerAction
        ]
    )
    func pendingGameCenterStatesKeepAdsClosed(
        connectionState: GameCenterConnectionState
    ) {
        let policy = AdAgePolicy.resolve(
            connectionState: connectionState,
            player: nil
        )

        #expect(policy == .pending)
        #expect(!policy.allowsAdBootstrap)
        #expect(!policy.isTaggedForUnderAgeOfConsent)
        #expect(!policy.usesChildAgeTreatment)
    }

    @Test func authenticatedUnderagePlayerUsesRestrictedTreatment() {
        let policy = AdAgePolicy.resolve(
            connectionState: .authenticated,
            player: player(isUnderage: true)
        )

        #expect(policy == .restricted)
        #expect(policy.allowsAdBootstrap)
        #expect(policy.isTaggedForUnderAgeOfConsent)
        #expect(policy.usesChildAgeTreatment)
    }

    @Test func authenticatedAdultPlayerUsesGeneralAudienceTreatment() {
        let policy = AdAgePolicy.resolve(
            connectionState: .authenticated,
            player: player(isUnderage: false)
        )

        #expect(policy == .unrestricted)
        #expect(policy.allowsAdBootstrap)
        #expect(!policy.isTaggedForUnderAgeOfConsent)
        #expect(!policy.usesChildAgeTreatment)
    }

    @Test func unavailableGameCenterUsesGeneralAudienceFallback() {
        let policy = AdAgePolicy.resolve(
            connectionState: .unavailable,
            player: nil
        )

        #expect(policy == .unknown)
        #expect(policy.allowsAdBootstrap)
        #expect(!policy.isTaggedForUnderAgeOfConsent)
        #expect(!policy.usesChildAgeTreatment)
    }

    @Test func authenticatedStateWithoutPlayerRemainsFailClosed() {
        let policy = AdAgePolicy.resolve(
            connectionState: .authenticated,
            player: nil
        )

        #expect(policy == .pending)
        #expect(!policy.allowsAdBootstrap)
    }

    @Test func pendingAgeTreatmentKeepsAFreeUserFailClosed() async {
        let service = AdService()

        await service.updateStatus(isPremium: false, agePolicy: .pending)

        #expect(service.state == .waitingForAgeTreatment)
        #expect(!service.canRequestAds)
        #expect(!service.isInterstitialReady)
        #expect(service.rewardedReadyPlacements.isEmpty)
    }

    private func player(isUnderage: Bool) -> GameCenterPlayerProfile {
        GameCenterPlayerProfile(
            gamePlayerID: "test-player",
            displayName: "Test Player",
            alias: "Tester",
            isUnderage: isUnderage,
            isMultiplayerGamingRestricted: false,
            isPersonalizedCommunicationRestricted: false
        )
    }
}
