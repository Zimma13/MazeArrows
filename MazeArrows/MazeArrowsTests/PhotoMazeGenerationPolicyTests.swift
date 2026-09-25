//
//  PhotoMazeGenerationPolicyTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

@MainActor
struct PhotoMazeGenerationPolicyTests {
    @Test func fiveSuccessfulFreeGenerationsAreAvailable() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)

        for expectedUsed in 1...5 {
            let access = store.photoMazeGenerationAccess(isPremium: false)
            #expect(access == .free)
            #expect(store.commitSuccessfulPhotoMazeGeneration(using: .free))
            #expect(store.progress.photoMazeFreeGenerationsUsed == expectedUsed)
        }

        #expect(store.photoMazeFreeGenerationsRemaining() == 0)
        #expect(store.photoMazeGenerationAccess(isPremium: false) == nil)
        #expect(!store.commitSuccessfulPhotoMazeGeneration(using: .free))
    }

    @Test func rewardedCreditIsPersistentUntilSuccessfulBuildCommitsIt() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)
        store.progress.photoMazeFreeGenerationsUsed = 5

        store.grantPhotoMazeRewardedCredit()

        #expect(store.photoMazeGenerationAccess(isPremium: false) == .rewarded)
        #expect(store.progress.photoMazeRewardedCredits == 1)
        #expect(store.commitSuccessfulPhotoMazeGeneration(using: .rewarded))
        #expect(store.progress.photoMazeRewardedCredits == 0)
        #expect(store.photoMazeGenerationAccess(isPremium: false) == nil)
    }

    @Test func premiumGenerationDoesNotConsumeFreeUseOrRewardedCredit() {
        let defaults = makeDefaults()
        let store = ProgressStore(defaults: defaults)
        store.progress.photoMazeFreeGenerationsUsed = 3
        store.grantPhotoMazeRewardedCredit()

        #expect(store.photoMazeGenerationAccess(isPremium: true) == .premium)
        #expect(store.commitSuccessfulPhotoMazeGeneration(using: .premium))
        #expect(store.progress.photoMazeFreeGenerationsUsed == 3)
        #expect(store.progress.photoMazeRewardedCredits == 1)
    }

    @Test func policySanitizesNegativeInputs() {
        let policy = PhotoMazeGenerationPolicy(freeGenerationLimit: -2)

        #expect(policy.freeGenerationsRemaining(used: -4) == 0)
        #expect(
            policy.access(
                isPremium: false,
                freeGenerationsUsed: -4,
                rewardedCredits: -1
            ) == nil
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "PhotoMazeGenerationPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
