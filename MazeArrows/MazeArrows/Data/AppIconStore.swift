//
//  AppIconStore.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Observation
import UIKit

@MainActor
protocol AppIconApplication: AnyObject {
    var supportsAlternateIcons: Bool { get }
    var alternateIconName: String? { get }

    func setAlternateIconName(
        _ alternateIconName: String?,
        completionHandler: (@Sendable ((any Error)?) -> Void)?
    )
}

extension AppThemeID {
    /// `nil` selects the primary Aurora icon.
    var alternateAppIconName: String? {
        switch self {
        case .aurora: return nil
        case .neon: return "AppIconNeon"
        case .petal: return "AppIconPetal"
        case .sakura: return "AppIconSakura"
        case .atlas: return "AppIconAtlas"
        case .nordic: return "AppIconNordic"
        }
    }

    var appIconPreviewAssetName: String {
        switch self {
        case .aurora: return "AppIconPreviewAurora"
        case .neon: return "AppIconPreviewNeon"
        case .petal: return "AppIconPreviewPetal"
        case .sakura: return "AppIconPreviewSakura"
        case .atlas: return "AppIconPreviewAtlas"
        case .nordic: return "AppIconPreviewNordic"
        }
    }
}

@MainActor
@Observable
final class AppIconStore {
    private(set) var pendingTheme: AppThemeID?
    private(set) var isApplying = false
    var isShowingChangeError = false

    @ObservationIgnored
    private let testApplication: (any AppIconApplication)?

    /// Production deliberately doesn't retain `UIApplication.shared` during
    /// SwiftUI `App` initialization. UIKit is resolved lazily only after the
    /// user confirms the system-level icon change.
    init(application: (any AppIconApplication)? = nil) {
        self.testApplication = application
    }

    func offerMatchingIcon(for theme: AppThemeID) {
        guard pendingTheme != theme else { return }
        pendingTheme = theme
    }

    func keepCurrentIcon() {
        pendingTheme = nil
    }

    func applyIcon(for theme: AppThemeID) {
        guard !isApplying else { return }

        pendingTheme = nil
        isShowingChangeError = false

        if let testApplication {
            requestIconChange(
                to: theme.alternateAppIconName,
                using: testApplication
            )
            return
        }

        let application = UIApplication.shared
        guard application.supportsAlternateIcons else {
            isShowingChangeError = true
            return
        }
        guard application.alternateIconName != theme.alternateAppIconName else {
            return
        }

        isApplying = true
        application.setAlternateIconName(theme.alternateAppIconName) { [weak self] error in
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isApplying = false
                self.isShowingChangeError = failed
            }
        }
    }

    private func requestIconChange(
        to iconName: String?,
        using application: any AppIconApplication
    ) {
        guard application.supportsAlternateIcons else {
            isShowingChangeError = true
            return
        }
        guard application.alternateIconName != iconName else { return }

        isApplying = true
        application.setAlternateIconName(iconName) { [weak self] error in
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isApplying = false
                self.isShowingChangeError = failed
            }
        }
    }
}
