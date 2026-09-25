//
//  Chapter.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

struct Chapter: Identifiable, Hashable, Sendable {
    let id: Int
    let difficulty: Difficulty
    let levelRange: ClosedRange<Int>
    let icon: String

    var levelCount: Int { levelRange.upperBound - levelRange.lowerBound + 1 }

    var title: String {
        switch id {
        case 1: return String(localized: "The Meadows")
        case 2: return String(localized: "The Forest")
        case 3: return String(localized: "The Mountains")
        case 4: return String(localized: "The Caves")
        case 5: return String(localized: "The Glacier")
        case 6: return String(localized: "The Summit")
        case 7: return String(localized: "The Void")
        default: return String(localized: "Chapter \(id)")
        }
    }

    var subtitle: String {
        String(localized: "Levels \(levelRange.lowerBound)–\(levelRange.upperBound)")
    }

    func completedCount(in completedLevels: Set<Int>) -> Int {
        levelRange.filter { completedLevels.contains($0) }.count
    }

    func totalStars(from stars: [Int: Int]) -> Int {
        levelRange.reduce(0) { $0 + (stars[$1] ?? 0) }
    }

    func maxStars() -> Int { levelCount * 3 }

    func isUnlocked(progress: PlayerProgress) -> Bool {
        id == 1 || progress.isUnlocked(levelRange.lowerBound)
    }

    func isComplete(progress: PlayerProgress) -> Bool {
        levelRange.allSatisfy { progress.completedLevels.contains($0) }
    }

    func starRatio(progress: PlayerProgress) -> Double {
        let earned = totalStars(from: progress.stars)
        let max = maxStars()
        return max > 0 ? Double(earned) / Double(max) : 0
    }

    static let all: [Chapter] = [
        Chapter(id: 1, difficulty: .easy,   levelRange: 1...25,    icon: "leaf.fill"),
        Chapter(id: 2, difficulty: .easy,   levelRange: 26...60,   icon: "tree.fill"),
        Chapter(id: 3, difficulty: .medium, levelRange: 61...95,   icon: "mountain.2.fill"),
        Chapter(id: 4, difficulty: .medium, levelRange: 96...130,  icon: "moon.stars.fill"),
        Chapter(id: 5, difficulty: .hard,   levelRange: 131...160, icon: "snowflake"),
        Chapter(id: 6, difficulty: .hard,   levelRange: 161...200, icon: "crown.fill"),
        Chapter(id: 7, difficulty: .expert, levelRange: 201...240, icon: "sparkles"),
    ]
}
