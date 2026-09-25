//
//  GameTheme.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  SwiftUI/SpriteKit palette derived from the design's themes.jsx.
//

import SwiftUI
import UIKit

struct GameTheme: Sendable {
    let id: AppThemeID
    let displayName: String

    // backgrounds
    /// Solid color matching the very top of `appBackground` — used by
    /// edge scrims that must blend seamlessly into the background.
    let appBackgroundTop: Color
    let appBackground: LinearGradient
    let boardBackground: Color
    let boardGrid: Color
    let surface: Color

    // ink
    let ink: Color
    let inkSoft: Color
    let inkMuted: Color

    // pieces
    let pieceStroke: Color
    let pieceGlow: Bool

    // accents
    let accent: Color
    let accent2: Color
    let danger: Color
    let heartFill: Color
    let success: Color

    // primary button
    let primaryGradient: LinearGradient
    let primaryShadow: Color
    let primaryText: Color
    let glassBorder: Color

    /// A contrast-safe gold for stars, completion borders and reward marks.
    /// The previous bright yellow disappeared on white cards.
    let achievementGold: Color

    /// Foreground for symbols placed on a solid danger-colored surface.
    /// Neon danger is intentionally bright, so it needs dark ink.
    var textOnDanger: Color { id == .neon ? boardBackground : .white }

    /// Foreground for symbols placed on the secondary accent fill.
    var textOnAccent2: Color { id == .neon ? boardBackground : .white }

    /// Foreground for compact labels placed directly on the primary accent.
    /// Neon pink is much brighter than the accents in the light themes.
    var textOnAccent: Color { id == .neon ? boardBackground : .white }

    /// Foreground for text placed on a solid success-colored surface.
    var textOnSuccess: Color { id == .neon ? boardBackground : .white }

    /// Opaque fallback used when Reduce Transparency is enabled.
    var glassSolid: Color { id == .neon ? hex(0x171333) : .white }

    /// Theme tint layered over Material so busy artwork never dominates text.
    var glassTint: Color { id == .neon ? hex(0x151031) : .white }

    /// Shadow for floating glass controls and cards.
    var glassShadow: Color {
        id == .neon ? .black.opacity(0.30) : ink.opacity(0.10)
    }

    /// Gold used as foreground on dark themes and as a compact badge fill.
    var rewardGold: Color {
        id == .neon
            ? adaptiveHex(0xFFD166, increased: 0xFFE29A)
            : achievementGold
    }

    /// Foreground for text placed on `rewardGold`.
    var textOnRewardGold: Color { id == .neon ? boardBackground : .white }

    static func theme(for id: AppThemeID) -> GameTheme {
        switch id {
        case .aurora: return aurora
        case .neon:   return neon
        case .petal:  return petal
        case .sakura: return sakura
        case .atlas:  return atlas
        case .nordic: return nordic
        }
    }

    static let aurora = GameTheme(
        id: .aurora,
        displayName: "Aurora Light",
        appBackgroundTop: hex(0xFFF7EE),
        appBackground: LinearGradient(
            colors: [hex(0xFFF7EE), hex(0xF5F0E6), hex(0xECE5D6)],
            startPoint: .top, endPoint: .bottom
        ),
        boardBackground: hex(0xFDFBF6),
        boardGrid: adaptiveHex(0x1A1B2E, normalAlpha: 0.10, increasedAlpha: 0.24),
        surface: .white,
        ink: hex(0x1A1B2E),
        inkSoft: adaptiveHex(0x3E3F5C, increased: 0x1A1B2E),
        inkMuted: adaptiveHex(0x5F607A, increased: 0x35364D),
        pieceStroke: hex(0x1F2042),
        pieceGlow: false,
        accent: adaptiveHex(0x4A4ABF, increased: 0x363695),
        accent2: adaptiveHex(0xA74420, increased: 0x7E2E12),
        danger: adaptiveHex(0xC3263D, increased: 0x961629),
        heartFill: adaptiveHex(0xC3263D, increased: 0x961629),
        success: adaptiveHex(0x217551, increased: 0x14553A),
        primaryGradient: LinearGradient(colors: [hex(0x5858C8), hex(0x3F3FA8)], startPoint: .top, endPoint: .bottom),
        primaryShadow: hex(0x2E2EA0),
        primaryText: .white,
        glassBorder: adaptiveHex(0x1A1B2E, normalAlpha: 0.20, increasedAlpha: 0.52),
        achievementGold: adaptiveHex(0x8A6200, increased: 0x604300)
    )

    static let neon = GameTheme(
        id: .neon,
        displayName: "Midnight Neon",
        appBackgroundTop: hex(0x1B1340),
        appBackground: LinearGradient(
            colors: [hex(0x1B1340), hex(0x0D0A24), hex(0x07061A)],
            startPoint: .top, endPoint: .bottom
        ),
        boardBackground: hex(0x0B0926),
        boardGrid: adaptiveHex(0xB47CFF, normalAlpha: 0.16, increasedAlpha: 0.32),
        surface: adaptiveHex(0xFFFFFF, normalAlpha: 0.10, increasedAlpha: 0.17),
        ink: hex(0xF2F0FF),
        inkSoft: adaptiveHex(0xC5C0E8, increased: 0xE5E1FF),
        inkMuted: adaptiveHex(0xAAA5D2, increased: 0xD5D1F2),
        pieceStroke: hex(0x5AF0FF),
        pieceGlow: true,
        accent: adaptiveHex(0xFF6BE8, increased: 0xFF9BF0),
        accent2: hex(0x5AF0FF),
        danger: adaptiveHex(0xFF7188, increased: 0xFFA0AE),
        heartFill: adaptiveHex(0xFF7188, increased: 0xFFA0AE),
        success: adaptiveHex(0x56F5B2, increased: 0x91FFD0),
        primaryGradient: LinearGradient(colors: [hex(0xA61B92), hex(0x702080)], startPoint: .top, endPoint: .bottom),
        primaryShadow: hex(0x7A1B95),
        primaryText: .white,
        glassBorder: adaptiveHex(0xFFFFFF, normalAlpha: 0.28, increasedAlpha: 0.62),
        achievementGold: adaptiveHex(0x987000, increased: 0xB88A00)
    )

    static let petal = GameTheme(
        id: .petal,
        displayName: "Petal Pastel",
        appBackgroundTop: hex(0xFDE9F0),
        appBackground: LinearGradient(
            colors: [hex(0xFDE9F0), hex(0xFFE9DD), hex(0xE7E2FB)],
            startPoint: .top, endPoint: .bottom
        ),
        boardBackground: hex(0xFFFBFA),
        boardGrid: adaptiveHex(0x4B3A66, normalAlpha: 0.10, increasedAlpha: 0.24),
        surface: .white,
        ink: hex(0x4B3A66),
        inkSoft: adaptiveHex(0x6B5B91, increased: 0x4B3A66),
        inkMuted: adaptiveHex(0x62557F, increased: 0x514565),
        pieceStroke: hex(0x7B6BA8),
        pieceGlow: false,
        accent: adaptiveHex(0x9E3C60, increased: 0x772541),
        accent2: adaptiveHex(0x357A67, increased: 0x245A4B),
        danger: adaptiveHex(0xB63852, increased: 0x8D223B),
        heartFill: adaptiveHex(0xB63852, increased: 0x8D223B),
        success: adaptiveHex(0x28705E, increased: 0x185241),
        primaryGradient: LinearGradient(colors: [hex(0xB83F68), hex(0x8F2D50)], startPoint: .top, endPoint: .bottom),
        primaryShadow: hex(0xE1638A),
        primaryText: .white,
        glassBorder: adaptiveHex(0x4B3A66, normalAlpha: 0.22, increasedAlpha: 0.52),
        achievementGold: adaptiveHex(0x8A6200, increased: 0x604300)
    )

    static let sakura = GameTheme(
        id: .sakura,
        displayName: "Sakura",
        appBackgroundTop: hex(0xF9EEEC),
        appBackground: LinearGradient(
            colors: [hex(0xF9EEEC), hex(0xF1D9D7), hex(0xE5C0BE)],
            startPoint: .top, endPoint: .bottom
        ),
        boardBackground: hex(0xFAF5F1),
        boardGrid: adaptiveHex(0x1A1310, normalAlpha: 0.10, increasedAlpha: 0.24),
        surface: .white,
        ink: hex(0x1A1310),
        inkSoft: adaptiveHex(0x5A453E, increased: 0x1A1310),
        inkMuted: adaptiveHex(0x634C44, increased: 0x4E3D37),
        pieceStroke: hex(0x1A1310),
        pieceGlow: false,
        accent: adaptiveHex(0xA53C3E, increased: 0x7E292B),
        accent2: adaptiveHex(0x805B1F, increased: 0x5E400F),
        danger: adaptiveHex(0xA53C3E, increased: 0x7E292B),
        heartFill: adaptiveHex(0xA53C3E, increased: 0x7E292B),
        success: adaptiveHex(0x487158, increased: 0x31543E),
        primaryGradient: LinearGradient(colors: [hex(0xA94446), hex(0x843032)], startPoint: .top, endPoint: .bottom),
        primaryShadow: hex(0x7C2C2E),
        primaryText: .white,
        glassBorder: adaptiveHex(0x1A1310, normalAlpha: 0.20, increasedAlpha: 0.52),
        achievementGold: adaptiveHex(0x8A6200, increased: 0x604300)
    )

    static let atlas = GameTheme(
        id: .atlas,
        displayName: "Atlas",
        appBackgroundTop: hex(0xF4E4CC),
        appBackground: LinearGradient(
            colors: [hex(0xF4E4CC), hex(0xE8C9A0), hex(0xD4A877)],
            startPoint: .top, endPoint: .bottom
        ),
        boardBackground: hex(0xFCF6EC),
        boardGrid: adaptiveHex(0x143C50, normalAlpha: 0.10, increasedAlpha: 0.24),
        surface: .white,
        ink: hex(0x0F3D4A),
        inkSoft: adaptiveHex(0x173F4B, increased: 0x0F3D4A),
        inkMuted: adaptiveHex(0x1F4652, increased: 0x153A45),
        pieceStroke: hex(0x0F3D4A),
        pieceGlow: false,
        accent: adaptiveHex(0xA93D1F, increased: 0x7D2812),
        accent2: adaptiveHex(0x805B1F, increased: 0x5E400F),
        danger: adaptiveHex(0xA93D1F, increased: 0x7D2812),
        heartFill: adaptiveHex(0xA93D1F, increased: 0x7D2812),
        success: adaptiveHex(0x2A6C63, increased: 0x185047),
        primaryGradient: LinearGradient(colors: [hex(0xB64A2B), hex(0x873016)], startPoint: .top, endPoint: .bottom),
        primaryShadow: hex(0x7A2D17),
        primaryText: .white,
        glassBorder: adaptiveHex(0x0F3D4A, normalAlpha: 0.22, increasedAlpha: 0.54),
        achievementGold: adaptiveHex(0x8A6200, increased: 0x604300)
    )

    static let nordic = GameTheme(
        id: .nordic,
        displayName: "Nordic",
        appBackgroundTop: hex(0xECEDE8),
        appBackground: LinearGradient(
            colors: [hex(0xECEDE8), hex(0xDDDFD7), hex(0xC9CCC0)],
            startPoint: .top, endPoint: .bottom
        ),
        boardBackground: hex(0xF6F6F1),
        boardGrid: adaptiveHex(0x283728, normalAlpha: 0.10, increasedAlpha: 0.24),
        surface: .white,
        ink: hex(0x1F2A1E),
        inkSoft: adaptiveHex(0x3F4E3D, increased: 0x1F2A1E),
        inkMuted: adaptiveHex(0x4B5949, increased: 0x384735),
        pieceStroke: hex(0x1F2A1E),
        pieceGlow: false,
        accent: adaptiveHex(0x8A4725, increased: 0x653117),
        accent2: adaptiveHex(0x526837, increased: 0x384A23),
        danger: adaptiveHex(0xA43C29, increased: 0x782719),
        heartFill: adaptiveHex(0xA43C29, increased: 0x782719),
        success: adaptiveHex(0x526837, increased: 0x384A23),
        primaryGradient: LinearGradient(colors: [hex(0x324230), hex(0x1F2A1E)], startPoint: .top, endPoint: .bottom),
        primaryShadow: hex(0x0F140E),
        primaryText: hex(0xF6F6F1),
        glassBorder: adaptiveHex(0x1F2A1E, normalAlpha: 0.20, increasedAlpha: 0.52),
        achievementGold: adaptiveHex(0x765300, increased: 0x533900)
    )
}

nonisolated private func hex(_ value: UInt32) -> Color {
    Color(
        red: Double((value >> 16) & 0xFF) / 255.0,
        green: Double((value >> 8) & 0xFF) / 255.0,
        blue: Double(value & 0xFF) / 255.0
    )
}

/// Resolves stronger variants automatically when iOS Increase Contrast is on.
nonisolated private func adaptiveHex(
    _ normal: UInt32,
    increased: UInt32? = nil,
    normalAlpha: CGFloat = 1,
    increasedAlpha: CGFloat = 1
) -> Color {
    Color(uiColor: UIColor { traits in
        let useIncreased = traits.accessibilityContrast == .high
        let value = useIncreased ? (increased ?? normal) : normal
        let alpha = useIncreased ? increasedAlpha : normalAlpha
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    })
}

extension Color {
    /// Converts Color to a UIColor in any rendering color space (used to pass
    /// SwiftUI colors into SpriteKit nodes).
    var uiColor: UIColor { UIColor(self) }
}
