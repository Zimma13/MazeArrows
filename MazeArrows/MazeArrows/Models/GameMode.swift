//
//  GameMode.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Top-level game-mode configurations that modify how a level is played.
//  Modes are applied on top of any handcrafted Level — they alter rules but
//  not content.
//

import Foundation

enum GameMode: String, Codable, CaseIterable, Sendable {
    /// Default. Lives count down; out-of-lives = fail.
    case classic
    /// No lives, no failure — pure flow.
    case relax
    /// Tight life count + time bonus on win.
    case challenge
    /// Countdown timer; reaching 0 fails the level.
    case timed
    /// Daily puzzle in relax flavor (no fail, peaceful).
    case zenDaily
    /// No assisted moves or path preview, and one fewer life.
    case hard

    var displayName: String {
        switch self {
        case .classic: return String(localized: "Classic")
        case .relax: return String(localized: "Relax")
        case .challenge: return String(localized: "Challenge")
        case .timed: return String(localized: "Timed")
        case .zenDaily: return String(localized: "Zen Daily")
        case .hard: return String(localized: "Hard mode")
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return String(localized: "Lives & stars")
        case .relax: return String(localized: "No lives, no pressure")
        case .challenge: return String(localized: "Limited mistakes")
        case .timed: return String(localized: "Beat the clock")
        case .zenDaily: return String(localized: "Daily, no fail")
        case .hard: return String(localized: "Less help, more pressure")
        }
    }

    var systemImage: String {
        switch self {
        case .classic: return "gamecontroller.fill"
        case .relax: return "leaf.fill"
        case .challenge: return "flag.checkered"
        case .timed: return "timer"
        case .zenDaily: return "moon.stars.fill"
        case .hard: return "bolt.heart.fill"
        }
    }

    /// True if this mode never fails the player.
    var isPeaceful: Bool {
        self == .relax || self == .zenDaily
    }

    /// Returns the lives override (nil = use level default).
    func livesOverride(levelLives: Int) -> Int? {
        switch self {
        case .relax, .zenDaily: return 99
        case .challenge:        return max(1, levelLives - 1)
        case .hard:             return max(1, levelLives - 1)
        case .classic, .timed:  return nil
        }
    }

    /// Countdown timer in seconds — nil means no timer.
    var countdownSeconds: Int? {
        switch self {
        case .timed: return 180
        default:     return nil
        }
    }

    var allowsHints: Bool { self != .hard }
    var allowsUndo: Bool { self != .hard }
    var allowsPathPreview: Bool { self != .hard }

    /// Modifiers available for master replays of completed story levels.
    static let masterModifiers: [GameMode] = [.challenge, .timed, .hard]
}
