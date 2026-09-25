//
//  LocalizationCompletenessTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing

struct LocalizationCompletenessTests {
    private let translatedLocales = [
        "de", "en-IN", "es", "es-MX", "fr", "hi", "id", "ja", "ko",
        "pt-BR", "pt-PT", "ru", "th", "zh-Hant"
    ]

    private var appSourceDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MazeArrows")
    }

    @Test func stringCatalogHasEveryDeclaredTranslation() throws {
        let catalog = try loadJSON(
            appSourceDirectory.appendingPathComponent("Localizable.xcstrings")
        )
        let strings = try #require(catalog["strings"] as? [String: Any])

        for (key, rawEntry) in strings {
            let entry = try #require(rawEntry as? [String: Any])
            #expect(
                entry["extractionState"] as? String != "stale",
                "Unused localization key: \(key)"
            )
            guard entry["shouldTranslate"] as? Bool != false else { continue }
            let localizations = entry["localizations"] as? [String: Any] ?? [:]

            for locale in translatedLocales {
                let localization = try #require(
                    localizations[locale],
                    "Missing \(locale) translation for \(key)"
                )
                let units = stringUnits(in: localization)
                #expect(!units.isEmpty, "No string unit for \(locale): \(key)")
                for unit in units {
                    #expect(unit["state"] as? String == "translated", "Unfinished \(locale): \(key)")
                    if !key.isEmpty {
                        #expect(!(unit["value"] as? String ?? "").isEmpty, "Empty \(locale): \(key)")
                    }
                }
            }
        }
    }

    @Test func onboardingTablesExactlyMatchActiveKeys() throws {
        let copyURL = appSourceDirectory
            .appendingPathComponent("Onboarding")
            .appendingPathComponent("OnboardingCopy.swift")
        let sourceKeys = localizationKeys(in: try String(contentsOf: copyURL, encoding: .utf8))
        #expect(!sourceKeys.isEmpty)

        for locale in translatedLocales {
            let tableURL = appSourceDirectory
                .appendingPathComponent("\(locale).lproj")
                .appendingPathComponent("Onboarding.strings")
            let tableKeys = localizationKeys(in: try String(contentsOf: tableURL, encoding: .utf8))
            #expect(tableKeys == sourceKeys, "Onboarding keys differ for \(locale)")
        }
    }

    @Test func photoMazeNameDoesNotFallBackToEnglish() throws {
        let catalog = try loadJSON(
            appSourceDirectory.appendingPathComponent("Localizable.xcstrings")
        )
        let strings = try #require(catalog["strings"] as? [String: Any])

        for key in [
            "Photo Maze",
            "PHOTO MAZE",
            "Choose a photo",
            "Choose another photo",
            "Unlimited Photo Maze creations"
        ] {
            let entry = try #require(strings[key] as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])
            for locale in translatedLocales where locale != "en-IN" {
                let localization = try #require(localizations[locale])
                let values = stringUnits(in: localization).compactMap { $0["value"] as? String }
                #expect(!values.isEmpty)
                #expect(values.allSatisfy { $0 != key }, "English fallback for \(locale): \(key)")
            }
        }
    }

    @Test func dynamicInterfaceCopyCannotBypassLocalization() throws {
        let photoLevelSource = try String(
            contentsOf: appSourceDirectory
                .appendingPathComponent("Views")
                .appendingPathComponent("PhotoLevelView.swift"),
            encoding: .utf8
        )
        #expect(photoLevelSource.contains("private var photoButtonTitle: String"))
        #expect(photoLevelSource.contains("String(localized: \"Choose a photo\")"))
        #expect(photoLevelSource.contains("String(localized: \"Choose another photo\")"))
        #expect(photoLevelSource.contains("Text(verbatim: localizedPhotoButtonTitle)"))
        #expect(!photoLevelSource.contains("let photoButtonTitle ="))

        let viewsDirectory = appSourceDirectory.appendingPathComponent("Views")
        let viewFiles = try FileManager.default.contentsOfDirectory(
            at: viewsDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }
        for file in viewFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            #expect(
                !source.contains("error.localizedDescription"),
                "Raw system error can bypass localization in \(file.lastPathComponent)"
            )
        }
    }

    private func loadJSON(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func stringUnits(in value: Any) -> [[String: Any]] {
        if let dictionary = value as? [String: Any] {
            var units: [[String: Any]] = []
            if let unit = dictionary["stringUnit"] as? [String: Any] {
                units.append(unit)
            }
            for nested in dictionary.values {
                units.append(contentsOf: stringUnits(in: nested))
            }
            return units
        }
        if let array = value as? [Any] {
            return array.flatMap(stringUnits)
        }
        return []
    }

    private func localizationKeys(in source: String) -> Set<String> {
        let expression = try! NSRegularExpression(pattern: #"onboarding\.[A-Za-z0-9_.]+"#)
        let range = NSRange(source.startIndex..., in: source)
        return Set(expression.matches(in: source, range: range).compactMap { match in
            guard let range = Range(match.range, in: source) else { return nil }
            return String(source[range])
        })
    }
}
