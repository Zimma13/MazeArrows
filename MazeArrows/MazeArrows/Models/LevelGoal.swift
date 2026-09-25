//
//  LevelGoal.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Win condition for a level. Defaults to `.clearAll` when not specified in
//  the JSON, which preserves the original "remove every piece" rule.
//

import Foundation

nonisolated enum LevelGoal: Codable, Hashable, Sendable {
    /// Default — clear every piece on the board.
    case clearAll
    /// Clear only the pieces in a given color group (gold, blue, etc.).
    case clearColorGroup(Int)
    /// Win without ever blocking. Also clears the board.
    case clearWithoutMistakes
    /// Keys (color group A) must be removed before their matching locks (group B).
    case keysBeforeLocks
    /// Win after freeing a specific piece id (treated as a "gem").
    case freePiece(String)
    /// Win if the board is cleared within `seconds` seconds.
    case clearInSeconds(Int)
    /// Win without using any hint.
    case noHints

    enum CodingKeys: String, CodingKey { case kind, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "clearAll":
            self = .clearAll
        case "clearColorGroup":
            let v = try c.decode(Int.self, forKey: .value)
            self = .clearColorGroup(v)
        case "clearWithoutMistakes":
            self = .clearWithoutMistakes
        case "keysBeforeLocks":
            self = .keysBeforeLocks
        case "freePiece":
            let v = try c.decode(String.self, forKey: .value)
            self = .freePiece(v)
        case "clearInSeconds":
            let v = try c.decode(Int.self, forKey: .value)
            self = .clearInSeconds(v)
        case "noHints":
            self = .noHints
        default:
            self = .clearAll
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .clearAll:
            try c.encode("clearAll", forKey: .kind)
        case .clearColorGroup(let v):
            try c.encode("clearColorGroup", forKey: .kind)
            try c.encode(v, forKey: .value)
        case .clearWithoutMistakes:
            try c.encode("clearWithoutMistakes", forKey: .kind)
        case .keysBeforeLocks:
            try c.encode("keysBeforeLocks", forKey: .kind)
        case .freePiece(let v):
            try c.encode("freePiece", forKey: .kind)
            try c.encode(v, forKey: .value)
        case .clearInSeconds(let v):
            try c.encode("clearInSeconds", forKey: .kind)
            try c.encode(v, forKey: .value)
        case .noHints:
            try c.encode("noHints", forKey: .kind)
        }
    }

    /// Short human-readable description of the goal.
    var displayText: String {
        switch self {
        case .clearAll: return String(localized: "Clear all arrows")
        case .clearColorGroup(let g): return String(localized: "Clear all color group \(g)")
        case .clearWithoutMistakes: return String(localized: "Clear without mistakes")
        case .keysBeforeLocks: return String(localized: "Keys before locks")
        case .freePiece: return String(localized: "Free the trapped piece")
        case .clearInSeconds(let s): return String(localized: "Clear in under \(s)s")
        case .noHints: return String(localized: "Clear without hints")
        }
    }
}
