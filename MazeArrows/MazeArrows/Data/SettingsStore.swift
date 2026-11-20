//
//  SettingsStore.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import Observation

enum AppThemeID: String, Codable, CaseIterable, Sendable {
    case aurora
    case neon
    case petal
    case sakura
    case atlas
    case nordic

    var displayName: String {
        switch self {
        case .aurora: return String(localized: "Aurora Light")
        case .neon:   return String(localized: "Midnight Neon")
        case .petal:  return String(localized: "Petal Pastel")
        case .sakura: return String(localized: "Sakura")
        case .atlas:  return String(localized: "Atlas")
        case .nordic: return String(localized: "Nordic")
        }
    }
}

struct AppSettings: Codable, Sendable {
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var themeID: AppThemeID
    var previewPathEnabled: Bool
    /// Adds a wider stroke beneath arrows. Off by default so photo colors
    /// remain visually faithful.
    var arrowOutlinesEnabled: Bool
    /// User-selected RGB color for the optional arrow outline.
    var arrowOutlineColor: PieceGroupPaletteColor
    /// Multi-level hint depth: 1 = area, 2 = piece (default), 3 = piece + ghost next move.
    var hintDepth: Int
    /// Legacy global mode picker, removed with the mode restructure —
    /// campaign is always classic, Zen replaced relax. Kept only so old
    /// persisted settings keep decoding; no gameplay reads it anymore.
    var selectedGameMode: GameMode

    static let defaults = AppSettings(
        soundEnabled: true,
        hapticsEnabled: true,
        themeID: .aurora,
        previewPathEnabled: true,
        arrowOutlinesEnabled: false,
        arrowOutlineColor: .init(red: 0.12, green: 0.12, blue: 0.16),
        hintDepth: 2,
        selectedGameMode: .classic
    )

    enum CodingKeys: String, CodingKey {
        case soundEnabled, hapticsEnabled, themeID, previewPathEnabled, arrowOutlinesEnabled
        case arrowOutlineColor
        case hintDepth, selectedGameMode
    }

    init(
        soundEnabled: Bool,
        hapticsEnabled: Bool,
        themeID: AppThemeID,
        previewPathEnabled: Bool,
        arrowOutlinesEnabled: Bool = false,
        arrowOutlineColor: PieceGroupPaletteColor = .init(red: 0.12, green: 0.12, blue: 0.16),
        hintDepth: Int = 2,
        selectedGameMode: GameMode = .classic
    ) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.themeID = themeID
        self.previewPathEnabled = previewPathEnabled
        self.arrowOutlinesEnabled = arrowOutlinesEnabled
        self.arrowOutlineColor = arrowOutlineColor
        self.hintDepth = hintDepth
        self.selectedGameMode = selectedGameMode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        soundEnabled = try c.decode(Bool.self, forKey: .soundEnabled)
        hapticsEnabled = try c.decode(Bool.self, forKey: .hapticsEnabled)
        themeID = try c.decode(AppThemeID.self, forKey: .themeID)
        previewPathEnabled = try c.decode(Bool.self, forKey: .previewPathEnabled)
        arrowOutlinesEnabled = (try? c.decode(Bool.self, forKey: .arrowOutlinesEnabled)) ?? false
        arrowOutlineColor = (try? c.decode(
            PieceGroupPaletteColor.self,
            forKey: .arrowOutlineColor
        )) ?? .init(red: 0.12, green: 0.12, blue: 0.16)
        hintDepth = (try? c.decode(Int.self, forKey: .hintDepth)) ?? 2
        selectedGameMode = (try? c.decode(GameMode.self, forKey: .selectedGameMode)) ?? .classic
    }
}

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()
    private let key = "MazeArrows.Settings.v1"
    private let defaults: UserDefaults

    var settings: AppSettings {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .defaults
        }
    }

    func resetToDefaults() {
        settings = .defaults
    }

    @discardableResult
    func selectTheme(_ id: AppThemeID, access: PremiumAccessPolicy) -> Bool {
        guard access.canUseTheme(id) else { return false }
        guard settings.themeID != id else { return true }
        settings.themeID = id
        return true
    }

    func enforceThemeAccess(_ access: PremiumAccessPolicy) {
        let resolved = access.resolvedTheme(settings.themeID)
        guard resolved != settings.themeID else { return }
        settings.themeID = resolved
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
