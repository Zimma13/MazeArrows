import Foundation
import Testing
@testable import MazeArrows

@MainActor
struct PaidEditionMigrationTests {
    @Test func previousThemeIsPreservedAndEveryThemePersists() throws {
        let suiteName = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let savedSettings = Data("""
            {"soundEnabled":false,"hapticsEnabled":true,"themeID":"nordic","previewPathEnabled":false}
            """.utf8)
        defaults.set(savedSettings, forKey: "MazeArrows.Settings.v1")
        let store = SettingsStore(defaults: defaults)
        #expect(store.settings.themeID == .nordic)

        for theme in AppThemeID.allCases {
            store.selectTheme(theme)
            let restored = SettingsStore(defaults: defaults).settings
            #expect(restored.themeID == theme)
            #expect(!restored.soundEnabled)
            #expect(!restored.previewPathEnabled)
        }
    }

    @Test(arguments: ["paywallIntro", "paywallTimeline", "paywallPlans"], [true, false])
    func oldOfferResumesAtFourthLesson(step: String, wasShown: Bool) throws {
        let suiteName = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let fields: [String: Any] = [
            "version": 1,
            "step": step,
            "paywallWasShown": wasShown,
            "starterRewardWasClaimed": false
        ]
        let snapshot = try JSONSerialization.data(withJSONObject: fields)
        defaults.set(snapshot, forKey: "MazeArrows.Onboarding.v1")
        let progress = ProgressStore(defaults: defaults)
        let onboarding = OnboardingStore(defaults: defaults, progressStore: progress)
        #expect(onboarding.shouldShow)
        #expect(onboarding.step == .tutorialFour)

        onboarding.move(to: .streak)
        onboarding.claimStarterReward(in: progress)
        let balance = progress.progress.coins
        let restored = OnboardingStore(defaults: defaults, progressStore: progress)
        #expect(restored.step == .pushPrompt)
        restored.claimStarterReward(in: progress)
        #expect(progress.progress.coins == balance)
    }
}
