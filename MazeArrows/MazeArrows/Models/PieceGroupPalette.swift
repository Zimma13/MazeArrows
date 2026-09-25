//
//  PieceGroupPalette.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

/// Renderer-independent RGB color used by both photo processing and SpriteKit.
/// Values stay in the 0...1 range and can be embedded in generated/shared levels.
nonisolated struct PieceGroupPaletteColor: Codable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }
}

/// Fallback palette for campaign levels and old shared levels. Photo levels
/// carry their own palette so their colors do not need to be approximated.
nonisolated enum PieceGroupPalette {
    static let colors: [PieceGroupPaletteColor] = [
        .init(red: 0.91, green: 0.62, blue: 0.66), // 1 rose
        .init(red: 0.45, green: 0.68, blue: 0.92), // 2 sky
        .init(red: 0.94, green: 0.74, blue: 0.38), // 3 amber
        .init(red: 0.52, green: 0.76, blue: 0.56), // 4 green
        .init(red: 0.72, green: 0.58, blue: 0.90), // 5 violet
        .init(red: 0.85, green: 0.33, blue: 0.31), // 6 red
        .init(red: 0.93, green: 0.56, blue: 0.28), // 7 orange
        .init(red: 0.36, green: 0.72, blue: 0.70), // 8 teal
        .init(red: 0.32, green: 0.42, blue: 0.68), // 9 navy
        .init(red: 0.62, green: 0.47, blue: 0.34), // 10 brown
        .init(red: 0.63, green: 0.65, blue: 0.69), // 11 gray
        .init(red: 0.86, green: 0.84, blue: 0.78), // 12 cream
        .init(red: 0.22, green: 0.24, blue: 0.31), // 13 ink
        .init(red: 0.80, green: 0.42, blue: 0.66), // 14 magenta
        .init(red: 0.89, green: 0.80, blue: 0.36), // 15 yellow
        .init(red: 0.33, green: 0.56, blue: 0.40), // 16 forest
    ]
}
