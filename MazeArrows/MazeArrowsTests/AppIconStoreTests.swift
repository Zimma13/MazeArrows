//
//  AppIconStoreTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Testing
@testable import MazeArrows

@MainActor
struct AppIconStoreTests {
    @Test func liveApplicationCanEvaluateAnIconProposal() {
        let store = AppIconStore()

        store.offerMatchingIcon(for: .neon)
        #expect(store.pendingTheme == .neon)
        store.keepCurrentIcon()

        #expect(store.pendingTheme == nil)
    }

    @Test func creatingAProposalNeverReadsTheSystemApplication() {
        let application = FakeAppIconApplication()
        let store = AppIconStore(application: application)

        store.offerMatchingIcon(for: .neon)

        #expect(store.pendingTheme == .neon)
        #expect(application.supportsReadCount == 0)
        #expect(application.alternateIconReadCount == 0)
        #expect(application.requestedIconNames.isEmpty)
    }

    @Test func rapidThemeChangesKeepOnlyTheLatestProposal() {
        let store = AppIconStore(application: FakeAppIconApplication())

        store.offerMatchingIcon(for: .aurora)
        store.offerMatchingIcon(for: .neon)
        store.offerMatchingIcon(for: .petal)

        #expect(store.pendingTheme == .petal)
        store.keepCurrentIcon()
        #expect(store.pendingTheme == nil)
    }

    @Test func everyThemeMapsToItsExpectedIconSet() {
        #expect(AppThemeID.aurora.alternateAppIconName == nil)
        #expect(AppThemeID.neon.alternateAppIconName == "AppIconNeon")
        #expect(AppThemeID.petal.alternateAppIconName == "AppIconPetal")
        #expect(AppThemeID.sakura.alternateAppIconName == "AppIconSakura")
        #expect(AppThemeID.atlas.alternateAppIconName == "AppIconAtlas")
        #expect(AppThemeID.nordic.alternateAppIconName == "AppIconNordic")
    }

    @Test func applyingAlreadyActiveIconDoesNotCallTheSystem() {
        let application = FakeAppIconApplication(alternateIconName: "AppIconNeon")
        let store = AppIconStore(application: application)

        store.offerMatchingIcon(for: .neon)
        store.applyIcon(for: .neon)

        #expect(store.pendingTheme == nil)
        #expect(application.requestedIconNames.isEmpty)
        #expect(!store.isShowingChangeError)
    }

    @Test func applyingProposalUsesTheThemeIconName() async {
        let application = FakeAppIconApplication()
        let store = AppIconStore(application: application)

        store.offerMatchingIcon(for: .petal)
        store.applyIcon(for: .petal)
        await Task.yield()

        #expect(application.requestedIconNames == ["AppIconPetal"])
        #expect(store.pendingTheme == nil)
        #expect(!store.isApplying)
        #expect(!store.isShowingChangeError)
    }

    @Test func applyingAuroraRestoresThePrimaryIcon() {
        let application = FakeAppIconApplication(alternateIconName: "AppIconNordic")
        let store = AppIconStore(application: application)

        store.offerMatchingIcon(for: .aurora)
        store.applyIcon(for: .aurora)

        #expect(application.requestedIconNames.count == 1)
        #expect(application.requestedIconNames[0] == nil)
    }

    @Test func failedSystemRequestKeepsAnErrorForTheUI() async {
        let application = FakeAppIconApplication(error: FakeIconError.failed)
        let store = AppIconStore(application: application)

        store.offerMatchingIcon(for: .sakura)
        store.applyIcon(for: .sakura)
        await Task.yield()

        #expect(store.isShowingChangeError)
    }

    @Test func unsupportedDevicesKeepTheProposalSafeUntilConfirmation() {
        let application = FakeAppIconApplication(supportsAlternateIcons: false)
        let store = AppIconStore(application: application)

        store.offerMatchingIcon(for: .atlas)
        #expect(store.pendingTheme == .atlas)
        store.applyIcon(for: .atlas)

        #expect(store.pendingTheme == nil)
        #expect(application.requestedIconNames.isEmpty)
        #expect(store.isShowingChangeError)
    }
}

@MainActor
private final class FakeAppIconApplication: AppIconApplication {
    private let configuredSupportsAlternateIcons: Bool
    private var storedAlternateIconName: String?
    private(set) var supportsReadCount = 0
    private(set) var alternateIconReadCount = 0
    private(set) var requestedIconNames: [String?] = []
    private let error: (any Error)?

    var supportsAlternateIcons: Bool {
        supportsReadCount += 1
        return configuredSupportsAlternateIcons
    }

    var alternateIconName: String? {
        alternateIconReadCount += 1
        return storedAlternateIconName
    }

    init(
        supportsAlternateIcons: Bool = true,
        alternateIconName: String? = nil,
        error: (any Error)? = nil
    ) {
        self.configuredSupportsAlternateIcons = supportsAlternateIcons
        self.storedAlternateIconName = alternateIconName
        self.error = error
    }

    func setAlternateIconName(
        _ alternateIconName: String?,
        completionHandler: (@Sendable ((any Error)?) -> Void)?
    ) {
        requestedIconNames.append(alternateIconName)
        if error == nil {
            storedAlternateIconName = alternateIconName
        }
        completionHandler?(error)
    }
}

private enum FakeIconError: Error {
    case failed
}
