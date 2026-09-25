//
//  PhotoMazeGenerationPolicy.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

struct PhotoMazeGenerationPolicy: Equatable, Sendable {
    static let standard = PhotoMazeGenerationPolicy(freeGenerationLimit: 5)

    let freeGenerationLimit: Int

    init(freeGenerationLimit: Int) {
        self.freeGenerationLimit = max(0, freeGenerationLimit)
    }

    func freeGenerationsRemaining(used: Int) -> Int {
        max(0, freeGenerationLimit - max(0, used))
    }

    func access(
        isPremium: Bool,
        freeGenerationsUsed: Int,
        rewardedCredits: Int
    ) -> PhotoMazeGenerationAccess? {
        if isPremium {
            return .premium
        }
        if freeGenerationsRemaining(used: freeGenerationsUsed) > 0 {
            return .free
        }
        if rewardedCredits > 0 {
            return .rewarded
        }
        return nil
    }
}
