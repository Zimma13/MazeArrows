// Generates the reusable App Store parrot level with the exact production
// ImageBoardBuilder -> PhotoMazeLevelBuilder pipeline. This is a host-side
// screenshot tool and is intentionally not part of the app target.

import CoreGraphics
import Foundation
import ImageIO

private enum ExportError: Error, CustomStringConvertible {
    case usage
    case unreadableImage(String)
    case maskFailed
    case generationFailed
    case validationFailed(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: export_parrot_fixture <input.png> <output.json> <output.swift>"
        case .unreadableImage(let path):
            return "could not read image at \(path)"
        case .maskFailed:
            return "ImageBoardBuilder could not create a mask"
        case .generationFailed:
            return "PhotoMazeLevelBuilder could not generate a level"
        case .validationFailed(let reason):
            return "fixture validation failed: \(reason)"
        }
    }
}

@main
private struct ParrotFixtureExporter {
    static func main() async throws {
        guard CommandLine.arguments.count == 4 else { throw ExportError.usage }

        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let jsonURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let swiftURL = URL(fileURLWithPath: CommandLine.arguments[3])

        guard
            let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw ExportError.unreadableImage(inputURL.path)
        }

        // 128 is the production builder's maximum supported detail. Width is
        // derived from the image aspect ratio by ImageBoardBuilder.
        guard let productionMask = ImageBoardBuilder.build(
            from: image,
            targetHeight: 128,
            invert: false,
            useAlphaMask: false
        ) else {
            throw ExportError.maskFailed
        }

        // The App Store source has an opaque white background. Otsu correctly
        // isolates almost all of the bird, but its brightest yellow collar is
        // close enough to white that those cells disappear from the mask. The
        // on-device Vision cutout keeps them because it uses alpha instead.
        // Restore only that known collar contour for this deterministic fixture
        // before the real PhotoMazeLevelBuilder creates its winding arrows.
        let (mask, collarZoneIndex) = restoringYellowCollar(in: productionMask)

        print("mask=\(mask.width)x\(mask.height) cells=\(mask.allCells.count) zones=\(mask.zones.map(\.count))")
        print("colors=\(mask.zoneColors.map { String(format: "%.4f,%.4f,%.4f", $0.r, $0.g, $0.b) })")

        var generatedLevel: Level?
        for await update in PhotoMazeLevelBuilder.updates(for: mask) {
            switch update {
            case .progress(let progress):
                print("progress=\(Int((progress * 100).rounded()))%")
            case .finished(let level):
                generatedLevel = level
            }
        }

        guard let generatedLevel else { throw ExportError.generationFailed }
        // The six-color production quantizer groups the parrot's small orange
        // beak with its much larger yellow collar. Keep the screenshot fixture
        // faithful to the dominant source region instead of rendering both as
        // orange. This changes only the screenshot palette.
        var screenshotPalette = generatedLevel.piecePalette
        if screenshotPalette.indices.contains(collarZoneIndex) {
            screenshotPalette[collarZoneIndex] = PieceGroupPaletteColor(
                red: 252.0 / 255.0,
                green: 198.0 / 255.0,
                blue: 5.0 / 255.0
            )
        }

        let level = Level(
            id: "screenshot_photo_parrot",
            index: 0,
            difficulty: generatedLevel.difficulty,
            width: generatedLevel.width,
            height: generatedLevel.height,
            lives: generatedLevel.lives,
            pieces: generatedLevel.pieces,
            piecePalette: screenshotPalette,
            obstacles: generatedLevel.obstacles,
            goal: generatedLevel.goal,
            threeStarMaxMistakes: generatedLevel.threeStarMaxMistakes,
            twoStarMaxMistakes: generatedLevel.twoStarMaxMistakes,
            name: "Photo Maze"
        )

        guard level.width == mask.width, level.height == mask.height else {
            throw ExportError.validationFailed("board dimensions changed")
        }
        guard Set(level.pieces.flatMap(\.cells)) == mask.allCells else {
            throw ExportError.validationFailed("pieces do not exactly cover the photo mask")
        }
        guard LevelSolver.solve(board: level.makeBoard())?.count == level.pieces.count else {
            throw ExportError.validationFailed("level is not fully solvable")
        }
        guard level.piecePalette.count == mask.zoneColors.count else {
            throw ExportError.validationFailed("source color palette was not preserved")
        }

        let prettyEncoder = JSONEncoder()
        prettyEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let prettyJSON = try prettyEncoder.encode(level)
        try prettyJSON.write(to: jsonURL, options: .atomic)

        let compactEncoder = JSONEncoder()
        compactEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let compactJSON = try compactEncoder.encode(level)
        guard let compactJSONString = String(data: compactJSON, encoding: .utf8) else {
            throw ExportError.validationFailed("could not encode UTF-8 fixture")
        }
        let swiftSource = makeSwiftFixture(json: compactJSONString)
        try Data(swiftSource.utf8).write(to: swiftURL, options: .atomic)

        // Decode the exact emitted data, rather than trusting only the source
        // value, so a malformed or lossy export cannot reach the harness.
        let decoded = try JSONDecoder().decode(Level.self, from: prettyJSON)
        guard decoded == level else {
            throw ExportError.validationFailed("JSON round-trip changed the level")
        }

        print("level=\(level.id) pieces=\(level.pieces.count) palette=\(level.piecePalette.count)")
        print("json=\(jsonURL.path) bytes=\(prettyJSON.count)")
        print("swift=\(swiftURL.path) bytes=\(swiftSource.utf8.count)")
    }

    /// Recreates the upper yellow collar retained by the app's alpha cutout.
    /// Coordinates are inclusive board scanlines measured from the source art;
    /// they stay inside the existing parrot silhouette's outer bounds.
    private static func restoringYellowCollar(
        in mask: ImageBoardResult
    ) -> (mask: ImageBoardResult, collarZoneIndex: Int) {
        let yellowReference = (r: 0.95, g: 0.72, b: 0.05)
        let collarZoneIndex = mask.zoneColors.indices.min {
            ImageBoardBuilder.colorDistance(mask.zoneColors[$0], yellowReference)
                < ImageBoardBuilder.colorDistance(mask.zoneColors[$1], yellowReference)
        } ?? max(0, mask.zones.count - 1)

        let scanlines: [(y: Int, x: ClosedRange<Int>)] = [
            (26, 45...46),
            (27, 44...46),
            (28, 43...46), (29, 43...46),
            (30, 42...46),
            (31, 41...47), (32, 41...47),
            (33, 41...48), (34, 41...48), (35, 41...48),
            (36, 41...48), (37, 41...48), (38, 41...48),
            (39, 42...49), (40, 42...49), (41, 42...49), (42, 42...49),
            (43, 43...49), (44, 43...49),
            (45, 44...49),
            (46, 45...49),
            (47, 46...49),
            (48, 47...49),
        ]
        let collarCells = Set(scanlines.flatMap { row in
            row.x.map { GridPoint(x: $0, y: row.y) }
        })

        var zones = mask.zones
        for index in zones.indices {
            zones[index].subtract(collarCells)
        }
        if zones.indices.contains(collarZoneIndex) {
            zones[collarZoneIndex].formUnion(collarCells)
        }

        return (
            ImageBoardResult(
                width: mask.width,
                height: mask.height,
                zones: zones,
                zoneColors: mask.zoneColors
            ),
            collarZoneIndex
        )
    }

    private static func makeSwiftFixture(json: String) -> String {
        """
        // Generated by AppStore/ScreenshotSources/Tools/export_parrot_fixture.swift.
        // The level came from the production photo pipeline at maximum detail.
        // Keep this declaration DEBUG-only so the fixture is absent from Release.

        #if DEBUG
        import Foundation

        enum ScreenshotParrotFixture {
            static func makeLevel() -> Level {
                do {
                    return try JSONDecoder().decode(Level.self, from: Data(levelJSON.utf8))
                } catch {
                    preconditionFailure("Invalid screenshot parrot fixture: \\(error)")
                }
            }

            private static let levelJSON = #"\(json)"#
        }
        #endif
        """
    }
}
