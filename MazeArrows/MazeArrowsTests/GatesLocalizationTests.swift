import Foundation
import Testing

struct GatesLocalizationTests {
    private let locales = [
        "en", "de", "en-IN", "es", "es-MX", "fr", "hi", "id", "ja", "ko",
        "pt-BR", "pt-PT", "ru", "th", "zh-Hant"
    ]

    private var appSourceDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MazeArrows")
    }

    @Test func everyGateMessageHasFinishedTranslationsAndSafeFormatArguments() throws {
        let catalog = try loadCatalog()
        #expect(catalog.sourceLanguage == "en")
        #expect(!catalog.strings.isEmpty)

        for (key, entry) in catalog.strings {
            let expectedArguments = try argumentSignature(key)
            for locale in locales {
                let unit = try #require(
                    entry.localizations[locale]?.stringUnit,
                    "Missing gate translation: \(locale), \(key)"
                )
                #expect(unit.state == "translated", "Unfinished gate translation: \(locale), \(key)")
                #expect(!unit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(
                    try argumentSignature(unit.value) == expectedArguments,
                    "Unsafe format arguments: \(locale), \(key)"
                )
                if !locale.hasPrefix("en") {
                    #expect(unit.value != key, "English gate fallback: \(locale), \(key)")
                }
            }
        }
    }

    @Test func gateCatalogCoversEveryActiveMessageWithoutUnusedEntries() throws {
        let catalog = try loadCatalog()
        let enumerator = try #require(FileManager.default.enumerator(
            at: appSourceDirectory,
            includingPropertiesForKeys: nil
        ))
        let call = try NSRegularExpression(
            pattern: #"\bString\s*\(\s*localized:\s*"((?:\\.|[^"\\])*)"\s*,\s*table:\s*"Gates""#
        )
        let interpolation = try NSRegularExpression(pattern: #"\\\((?:[^()]|\([^()]*\))*\)"#)
        var activeMessages = Set<String>()
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for match in call.matches(in: source, range: range) {
                let literalRange = try #require(Range(match.range(at: 1), in: source))
                let literal = String(source[literalRange])
                // Compare message structure independently of Swift expression
                // spelling; the argument types are checked against every locale
                // above, including reordered positional format arguments.
                activeMessages.insert(interpolation.stringByReplacingMatches(
                    in: literal,
                    range: NSRange(literal.startIndex..., in: literal),
                    withTemplate: "<argument>"
                ))
            }
        }
        #expect(!activeMessages.isEmpty)
        let catalogMessages = try Set(catalog.strings.keys.map { key in
            try formatPattern.stringByReplacingMatches(
                in: key,
                range: NSRange(key.startIndex..., in: key),
                withTemplate: "<argument>"
            )
        })
        #expect(activeMessages == catalogMessages)
    }

    private var formatPattern: NSRegularExpression {
        get throws { try NSRegularExpression(pattern: #"%(?:(\d+)\$)?(lld|@)"#) }
    }

    private func argumentSignature(_ value: String) throws -> [Int: String] {
        let pattern = try formatPattern
        let matches = pattern.matches(in: value, range: NSRange(value.startIndex..., in: value))
        var signature: [Int: String] = [:]
        var usesPositions = false
        var usesImplicitOrder = false
        for (offset, match) in matches.enumerated() {
            let typeRange = try #require(Range(match.range(at: 2), in: value))
            let type = String(value[typeRange])
            let position: Int
            if let positionRange = Range(match.range(at: 1), in: value) {
                position = try #require(Int(value[positionRange]))
                usesPositions = true
            } else {
                position = offset + 1
                usesImplicitOrder = true
            }
            #expect(position > 0)
            if let previous = signature[position] { #expect(previous == type) }
            signature[position] = type
        }
        #expect(!(usesPositions && usesImplicitOrder), "Mixed positional and implicit arguments: \(value)")
        let remainder = pattern.stringByReplacingMatches(
            in: value,
            range: NSRange(value.startIndex..., in: value),
            withTemplate: ""
        ).replacingOccurrences(of: "%%", with: "")
        #expect(!remainder.contains("%"), "Unsupported or broken format placeholder: \(value)")
        return signature
    }

    private func loadCatalog() throws -> Catalog {
        try JSONDecoder().decode(
            Catalog.self,
            from: Data(contentsOf: appSourceDirectory.appendingPathComponent("Gates.xcstrings"))
        )
    }

    private struct Catalog: Decodable {
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    private struct Entry: Decodable {
        let localizations: [String: Localization]
    }

    private struct Localization: Decodable {
        let stringUnit: Unit
    }

    private struct Unit: Decodable {
        let state: String
        let value: String
    }
}
