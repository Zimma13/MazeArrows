import Foundation
import SwiftUI
import Testing
@testable import MazeArrows

struct PhotoMazeGenerationTests {
    @MainActor @Test func photoInkIsReadableAndPreservesVisibleSamplesAcrossThemes() {
        let samples: [PieceGroupPaletteColor] = [
            .init(red: 0, green: 0, blue: 0),
            .init(red: 33 / 255, green: 40 / 255, blue: 57 / 255),
            .init(red: 0.98, green: 0.96, blue: 0.91),
            .init(red: 1, green: 1, blue: 1),
            .init(red: 0.73, green: 0.1, blue: 0.28),
            .init(red: 0, green: 0, blue: 1)
        ]
        func luminance(_ color: PieceGroupPaletteColor) -> Double {
            func linear(_ value: Double) -> Double {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
        }
        for id in AppThemeID.allCases {
            let theme = GameTheme.theme(for: id)
            let background = theme.boardBackground.resolve(in: EnvironmentValues())
            let board = luminance(.init(red: Double(background.red), green: Double(background.green), blue: Double(background.blue)))
            func ratio(_ ink: PieceGroupPaletteColor) -> Double {
                let light = luminance(ink)
                return (max(board, light) + 0.05) / (min(board, light) + 0.05)
            }
            for sample in samples {
                let ink = theme.photoInk(sample)
                func displayByte(_ channel: Double) -> Double {
                    (channel * 255).rounded() / 255
                }
                if ratio(sample) < 4.5 {
                    #expect(ratio(.init(red: displayByte(ink.red), green: displayByte(ink.green), blue: displayByte(ink.blue))) >= 4.5)
                }
                #expect(ratio(ink) >= 4.5)
                if ratio(sample) >= 4.5 {
                    #expect(ink == sample)
                }
            }
        }
    }

    @Test func buildsSixPlayableMazesInOneSession() async throws {
        let mask = ImageBoardResult(
            width: 4,
            height: 4,
            zones: [[GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)]],
            zoneColors: [(0.2, 0.4, 0.6)]
        )
        var identifiers = Set<String>()
        for _ in 0..<6 {
            var result: Level?
            for await update in PhotoMazeLevelBuilder.updates(for: mask) {
                if case .finished(let level) = update { result = level }
            }
            let level = try #require(result)
            #expect(level.pieces.count == 1)
            identifiers.insert(level.id)
        }
        #expect(identifiers.count == 6)
    }
}
