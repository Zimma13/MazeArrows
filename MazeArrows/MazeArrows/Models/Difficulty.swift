//
//  Difficulty.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

nonisolated enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy
    case medium
    case hard
    case expert

    var displayName: String {
        switch self {
        case .easy: return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard: return String(localized: "Hard")
        case .expert: return String(localized: "Expert")
        }
    }

    var order: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .expert: return 3
        }
    }
}
