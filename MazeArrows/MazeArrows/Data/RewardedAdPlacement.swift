//
//  RewardedAdPlacement.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

enum RewardedAdPlacement: String, CaseIterable, Sendable {
    case hint
    case undo
    case revive
    case photoMaze

    /// Ads worth keeping warm during ordinary gameplay. Photo Maze is loaded
    /// only when that flow is opened, so launch does not make an unused request.
    static let resourceOffers: [RewardedAdPlacement] = [.hint, .undo, .revive]

    func adUnitID(in configuration: AdMobConfiguration) -> String {
        switch self {
        case .hint:      return configuration.rewardedHint
        case .undo:      return configuration.rewardedUndo
        case .revive:    return configuration.rewardedRevive
        case .photoMaze: return configuration.rewardedPhotoMaze
        }
    }
}
