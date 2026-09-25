#!/usr/bin/env swift

import CoreGraphics
import CoreImage
import CoreText
import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Configuration

private let sourceDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .standardizedFileURL

private struct Options {
    var validateOnly = false
    var locale = "en-US"
    var localeWasExplicit = false
    var inputRootWasExplicit = false
    var outputRootWasExplicit = false
    var manifestWasExplicit = false
    var contactSheetWasExplicit = false
    var inputRoot = sourceDirectory
        .appendingPathComponent("_captures/en-US", isDirectory: true)
    var outputRoot = sourceDirectory
        .appendingPathComponent("Generated/en-US", isDirectory: true)
    var manifest = sourceDirectory.appendingPathComponent("screenshots.en-US.json")
    var photo = sourceDirectory.appendingPathComponent("parrot-photo-maze-compact-v2.png")
    var contactSheet = sourceDirectory
        .appendingPathComponent("Review/en-US_contact-sheet.png")
}

private struct Manifest: Decodable {
    let schemaVersion: Int
    let locale: String
    let captureLocale: String
    let slides: [Slide]
}

private struct Slide: Decodable {
    let id: String
    let filename: String
    let headline: [String]
    let accentLine: Int
    let accent: String
    let support: [String]
    let backgroundCapture: String
    let template: String
}

private struct SlideBlueprint {
    let id: String
    let filename: String
    let accent: String
    let backgroundCapture: String
    let template: String
}

private let captureLocaleByStorefront = [
    "en-US": "en-US",
    "ja": "ja",
    "de-DE": "de",
    "ko": "ko",
    "zh-Hant": "zh-Hant",
    "pt-BR": "pt-BR",
    "es-MX": "es-MX",
    "fr-FR": "fr",
    "fr-CA": "fr",
    "en-GB": "en-US",
    "en-CA": "en-US",
    "en-AU": "en-US",
    "es-ES": "es",
]

private let slideBlueprints = [
    SlideBlueprint(
        id: "photoMaze",
        filename: "01_your-photo-your-maze.png",
        accent: "pink",
        backgroundCapture: "photo-game",
        template: "photoToMaze"
    ),
    SlideBlueprint(
        id: "freeArrow",
        filename: "02_find-the-free-arrow.png",
        accent: "cyan",
        backgroundCapture: "free-arrow",
        template: "heroDevice"
    ),
    SlideBlueprint(
        id: "combo",
        filename: "03_watch-it-all-unravel.png",
        accent: "gold",
        backgroundCapture: "combo",
        template: "combo"
    ),
    SlideBlueprint(
        id: "worlds",
        filename: "04_240-levels-7-worlds.png",
        accent: "pink",
        backgroundCapture: "worlds",
        template: "worlds"
    ),
    SlideBlueprint(
        id: "daily",
        filename: "05_fresh-maze-every-day.png",
        accent: "gold",
        backgroundCapture: "daily",
        template: "dailyAndQuests"
    ),
]

private enum DeviceKind: String, CaseIterable {
    case iPhone = "iPhone-6.9"
    case iPad = "iPad-13"

    var pixelSize: CGSize {
        switch self {
        case .iPhone: CGSize(width: 1320, height: 2868)
        case .iPad: CGSize(width: 2064, height: 2752)
        }
    }
}

private let captureNames = [
    "photo-game",
    "free-arrow",
    "combo",
    "worlds",
    "daily",
    "quests",
]

private enum ScriptError: Error, CustomStringConvertible {
    case problems([String])
    case message(String)

    var description: String {
        switch self {
        case .problems(let values): values.joined(separator: "\n")
        case .message(let value): value
        }
    }
}

// MARK: - Color and canvas

private struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ hex: UInt32, alpha: CGFloat = 1) {
        red = CGFloat((hex >> 16) & 0xFF) / 255
        green = CGFloat((hex >> 8) & 0xFF) / 255
        blue = CGFloat(hex & 0xFF) / 255
        self.alpha = alpha
    }

    var cgColor: CGColor {
        CGColor(
            srgbRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    func opacity(_ value: CGFloat) -> RGBA {
        RGBA(
            red: red,
            green: green,
            blue: blue,
            alpha: value
        )
    }

    private init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

private enum Palette {
    static let top = RGBA(0x1B1340)
    static let middle = RGBA(0x0D0A24)
    static let bottom = RGBA(0x07061A)
    static let ink = RGBA(0xF2F0FF)
    static let inkSoft = RGBA(0xC5C0E8)
    static let cyan = RGBA(0x5AF0FF)
    static let pink = RGBA(0xFF6BE8)
    static let gold = RGBA(0xFFD166)
    static let success = RGBA(0x56F5B2)
    static let danger = RGBA(0xFF7188)
    static let shell = RGBA(0x080715)

    static func accent(named name: String) -> RGBA {
        switch name {
        case "cyan": cyan
        case "gold": gold
        case "success": success
        case "danger": danger
        default: pink
        }
    }
}

private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

private final class RasterCanvas {
    let width: Int
    let height: Int
    let context: CGContext

    var size: CGSize { CGSize(width: width, height: height) }

    init(size: CGSize) throws {
        width = Int(size.width.rounded())
        height = Int(size.height.rounded())
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw ScriptError.message("Unable to allocate an RGB canvas \(width)x\(height).")
        }
        self.context = context
        context.interpolationQuality = .high
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
    }

    func quartzRect(_ topLeftRect: CGRect) -> CGRect {
        CGRect(
            x: topLeftRect.minX,
            y: CGFloat(height) - topLeftRect.maxY,
            width: topLeftRect.width,
            height: topLeftRect.height
        )
    }

    func quartzPoint(_ topLeftPoint: CGPoint) -> CGPoint {
        CGPoint(x: topLeftPoint.x, y: CGFloat(height) - topLeftPoint.y)
    }

    func makeImage() throws -> CGImage {
        guard let image = context.makeImage() else {
            throw ScriptError.message("Unable to create the final CGImage.")
        }
        return image
    }
}

// MARK: - Input and output

private struct LoadedImage {
    let url: URL
    let image: CGImage
    let width: Int
    let height: Int
}

private func loadImage(at url: URL) throws -> LoadedImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ScriptError.message("Unable to decode PNG: \(url.path)")
    }
    return LoadedImage(url: url, image: image, width: image.width, height: image.height)
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw ScriptError.message("Unable to create PNG encoder for \(url.path)")
    }

    let properties: [CFString: Any] = [
        kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
        kCGImagePropertyPNGDictionary: [
            kCGImagePropertyPNGsRGBIntent: 0,
        ],
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw ScriptError.message("PNG encoding failed for \(url.path)")
    }

    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try (data as Data).write(to: url, options: .atomic)
}

private func loadManifest(at url: URL) throws -> Manifest {
    do {
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    } catch {
        throw ScriptError.message("Unable to read manifest \(url.path): \(error)")
    }
}

private func captureURL(root: URL, device: DeviceKind, name: String) -> URL {
    root
        .appendingPathComponent(device.rawValue, isDirectory: true)
        .appendingPathComponent("\(name).png")
}

private func validateManifest(_ manifest: Manifest) throws {
    var problems: [String] = []
    if manifest.schemaVersion != 1 {
        problems.append("Manifest schemaVersion must be 1, found \(manifest.schemaVersion).")
    }
    guard let expectedCaptureLocale = captureLocaleByStorefront[manifest.locale] else {
        let locales = captureLocaleByStorefront.keys.sorted().joined(separator: ", ")
        throw ScriptError.message(
            "Unsupported storefront locale \(manifest.locale). Expected one of: \(locales)."
        )
    }
    if manifest.captureLocale != expectedCaptureLocale {
        problems.append(
            "Manifest \(manifest.locale) must use captureLocale \(expectedCaptureLocale), " +
            "found \(manifest.captureLocale)."
        )
    }
    if manifest.slides.count != slideBlueprints.count {
        problems.append(
            "Manifest must contain exactly \(slideBlueprints.count) slides, " +
            "found \(manifest.slides.count)."
        )
    }

    for (index, pair) in zip(manifest.slides, slideBlueprints).enumerated() {
        let slide = pair.0
        let blueprint = pair.1
        if slide.id != blueprint.id {
            problems.append("Slide \(index + 1) id must be \(blueprint.id), found \(slide.id).")
        }
        if slide.filename != blueprint.filename {
            problems.append(
                "Slide \(slide.id) filename must be \(blueprint.filename), found \(slide.filename)."
            )
        }
        if slide.accent != blueprint.accent {
            problems.append("Slide \(slide.id) accent must be \(blueprint.accent), found \(slide.accent).")
        }
        if slide.backgroundCapture != blueprint.backgroundCapture {
            problems.append(
                "Slide \(slide.id) backgroundCapture must be \(blueprint.backgroundCapture), " +
                "found \(slide.backgroundCapture)."
            )
        }
        if slide.template != blueprint.template {
            problems.append(
                "Slide \(slide.id) template must be \(blueprint.template), found \(slide.template)."
            )
        }
        if slide.headline.isEmpty || slide.headline.count > 2 {
            problems.append("Slide \(slide.id) needs 1 or 2 headline lines.")
        }
        if slide.support.isEmpty || slide.support.count > 2 {
            problems.append("Slide \(slide.id) needs 1 or 2 supporting-copy lines.")
        }
        if !slide.headline.indices.contains(slide.accentLine) {
            problems.append("Slide \(slide.id) has an invalid accentLine.")
        }

        for (kind, lines) in [("headline", slide.headline), ("support", slide.support)] {
            for (lineIndex, line) in lines.enumerated() {
                if line.isEmpty {
                    problems.append("Slide \(slide.id) \(kind) line \(lineIndex + 1) is empty.")
                }
                if line != line.trimmingCharacters(in: .whitespacesAndNewlines) {
                    problems.append(
                        "Slide \(slide.id) \(kind) line \(lineIndex + 1) has leading or trailing whitespace."
                    )
                }
                if line.contains("\n") || line.contains("\r") {
                    problems.append(
                        "Slide \(slide.id) \(kind) line \(lineIndex + 1) contains an embedded newline."
                    )
                }
                if line != line.precomposedStringWithCanonicalMapping {
                    problems.append(
                        "Slide \(slide.id) \(kind) line \(lineIndex + 1) must use NFC Unicode normalization."
                    )
                }
            }
        }
    }
    if !problems.isEmpty { throw ScriptError.problems(problems) }
}

private func validateInputs(options: Options, manifest: Manifest) throws -> [DeviceKind: [String: LoadedImage]] {
    var problems: [String] = []
    var result: [DeviceKind: [String: LoadedImage]] = [:]

    if !FileManager.default.fileExists(atPath: options.photo.path) {
        problems.append("Missing shared photo: \(options.photo.path)")
    }

    for device in DeviceKind.allCases {
        var captures: [String: LoadedImage] = [:]
        for name in captureNames {
            let url = captureURL(root: options.inputRoot, device: device, name: name)
            guard FileManager.default.fileExists(atPath: url.path) else {
                problems.append("Missing capture: \(url.path)")
                continue
            }
            do {
                let loaded = try loadImage(at: url)
                let expected = device.pixelSize
                if loaded.width != Int(expected.width) || loaded.height != Int(expected.height) {
                    problems.append(
                        "Wrong capture size: \(url.path) is \(loaded.width)x\(loaded.height); " +
                        "expected \(Int(expected.width))x\(Int(expected.height))."
                    )
                }
                captures[name] = loaded
            } catch {
                problems.append(String(describing: error))
            }
        }
        result[device] = captures
    }

    if !problems.isEmpty {
        let intro = "Screenshot rendering stopped. Real native captures are required:"
        throw ScriptError.problems([intro] + problems.map { "  - \($0)" })
    }

    let photo = try loadImage(at: options.photo)
    if photo.width < 1000 || photo.height < 1200 {
        throw ScriptError.message(
            "Shared photo is too small: \(photo.width)x\(photo.height) at \(photo.url.path)"
        )
    }

    _ = manifest
    return result
}

// MARK: - Typography

private enum FontWeight {
    case heavy
    case semibold

    var postScriptName: String {
        switch self {
        case .heavy: "SFProRounded-Heavy"
        case .semibold: "SFProRounded-Semibold"
        }
    }

    var fileURL: URL {
        URL(fileURLWithPath: "/Library/Fonts/\(postScriptName.replacingOccurrences(of: "SFProRounded-", with: "SF-Pro-Rounded-")).otf")
    }
}

private func prepareFonts() throws {
    var problems: [String] = []
    for weight in [FontWeight.heavy, .semibold] {
        let url = weight.fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            problems.append("Missing font: \(url.path)")
            continue
        }
        var error: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        let font = CTFontCreateWithName(weight.postScriptName as CFString, 24, nil)
        let resolved = CTFontCopyPostScriptName(font) as String
        if resolved != weight.postScriptName {
            problems.append("Font \(weight.postScriptName) resolved as \(resolved).")
        }
    }
    if !problems.isEmpty { throw ScriptError.problems(problems) }
}

private struct TextMetrics {
    let line: CTLine
    let width: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
}

private func isCJKLocale(_ locale: String) -> Bool {
    locale == "ja" || locale == "ko" || locale.hasPrefix("zh-")
}

private func headlineTracking(for locale: String) -> CGFloat {
    isCJKLocale(locale) ? 0 : -1.2
}

private func textMetrics(
    _ text: String,
    size: CGFloat,
    weight: FontWeight,
    color: RGBA,
    tracking: CGFloat,
    locale: String
) -> TextMetrics {
    let font = CTFontCreateWithName(weight.postScriptName as CFString, size, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        NSAttributedString.Key(kCTKernAttributeName as String): tracking,
        NSAttributedString.Key(kCTLanguageAttributeName as String): locale,
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
    return TextMetrics(line: line, width: width, ascent: ascent, descent: descent)
}

private func fittingFontSize(
    lines: [String],
    maxWidth: CGFloat,
    maximum: CGFloat,
    minimum: CGFloat,
    weight: FontWeight,
    tracking: CGFloat,
    locale: String
) throws -> CGFloat {
    var size = maximum
    while size >= minimum {
        let fits = lines.allSatisfy {
            textMetrics(
                $0,
                size: size,
                weight: weight,
                color: Palette.ink,
                tracking: tracking,
                locale: locale
            ).width <= maxWidth
        }
        if fits { return size }
        size -= 2
    }
    throw ScriptError.message("Copy does not fit at the minimum font size: \(lines.joined(separator: " / "))")
}

private func lineContainsMissingGlyph(_ line: CTLine) -> Bool {
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    for run in runs {
        let count = CTRunGetGlyphCount(run)
        guard count > 0 else { continue }
        var glyphs = [CGGlyph](repeating: 0, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        if glyphs.contains(0) { return true }
    }
    return false
}

private func validateGlyphCoverage(_ manifest: Manifest) throws {
    var problems: [String] = []
    let tracking = headlineTracking(for: manifest.locale)
    for slide in manifest.slides {
        for (kind, lines, weight, lineTracking) in [
            ("headline", slide.headline, FontWeight.heavy, tracking),
            ("support", slide.support, FontWeight.semibold, CGFloat(0)),
        ] {
            for (index, text) in lines.enumerated() {
                let metrics = textMetrics(
                    text,
                    size: 64,
                    weight: weight,
                    color: Palette.ink,
                    tracking: lineTracking,
                    locale: manifest.locale
                )
                if lineContainsMissingGlyph(metrics.line) {
                    problems.append(
                        "Slide \(slide.id) \(kind) line \(index + 1) contains a missing font glyph: \(text)"
                    )
                }
            }
        }
    }
    if !problems.isEmpty { throw ScriptError.problems(problems) }
}

private func drawTextLine(
    on canvas: RasterCanvas,
    text: String,
    top: CGFloat,
    size: CGFloat,
    weight: FontWeight,
    color: RGBA,
    tracking: CGFloat,
    shadow: Bool,
    locale: String = "en-US",
    centerX: CGFloat? = nil
) {
    let metrics = textMetrics(
        text,
        size: size,
        weight: weight,
        color: color,
        tracking: tracking,
        locale: locale
    )
    let x = (centerX ?? CGFloat(canvas.width) / 2) - metrics.width / 2
    let baseline = CGFloat(canvas.height) - top - metrics.ascent

    let context = canvas.context
    context.saveGState()
    context.textMatrix = .identity
    if shadow {
        context.setShadow(
            offset: CGSize(width: 0, height: -12),
            blur: 28,
            color: RGBA(0x000000, alpha: 0.48).cgColor
        )
    }
    context.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(metrics.line, context)
    context.restoreGState()
}

private func drawCopy(
    slide: Slide,
    locale: String,
    device: DeviceKind,
    canvas: RasterCanvas
) throws {
    let config: (
        maxWidth: CGFloat,
        top: CGFloat,
        headlineMax: CGFloat,
        headlineMin: CGFloat,
        lineHeightFactor: CGFloat,
        supportMax: CGFloat,
        supportMin: CGFloat,
        gap: CGFloat
    ) = device == .iPhone
        ? (1152, 124, 116, 92, 1.02, 44, 36, 30)
        : (1812, 108, 140, 108, 1.01, 54, 44, 34)
    let titleTracking = headlineTracking(for: locale)
    let headlineSize = try fittingFontSize(
        lines: slide.headline,
        maxWidth: config.maxWidth,
        maximum: config.headlineMax,
        minimum: config.headlineMin,
        weight: .heavy,
        tracking: titleTracking,
        locale: locale
    )
    let headlineLineHeight = headlineSize * config.lineHeightFactor
    let accent = Palette.accent(named: slide.accent)
    for (index, line) in slide.headline.enumerated() {
        drawTextLine(
            on: canvas,
            text: line,
            top: config.top + CGFloat(index) * headlineLineHeight,
            size: headlineSize,
            weight: .heavy,
            color: index == slide.accentLine ? accent : Palette.ink,
            tracking: titleTracking,
            shadow: true,
            locale: locale
        )
    }

    let supportLines = slide.support
    let supportSize = try fittingFontSize(
        lines: supportLines,
        maxWidth: config.maxWidth,
        maximum: config.supportMax,
        minimum: config.supportMin,
        weight: .semibold,
        tracking: 0,
        locale: locale
    )
    let supportTop = config.top + CGFloat(slide.headline.count) * headlineLineHeight + config.gap
    let supportLineHeight = supportSize * 1.25
    for (index, line) in supportLines.enumerated() {
        drawTextLine(
            on: canvas,
            text: line,
            top: supportTop + CGFloat(index) * supportLineHeight,
            size: supportSize,
            weight: .semibold,
            color: Palette.inkSoft,
            tracking: 0,
            shadow: true,
            locale: locale
        )
    }

    let bottom = supportTop + CGFloat(supportLines.count) * supportLineHeight
    let safeBottom: CGFloat = device == .iPhone ? 640 : 560
    if bottom > safeBottom {
        throw ScriptError.message("Copy exceeded the top safe zone on \(device.rawValue): \(slide.id)")
    }
}

// MARK: - Drawing helpers

private enum VerticalAlignment {
    case center
    case top
}

private func aspectFillRect(
    image: CGImage,
    destination: CGRect,
    verticalAlignment: VerticalAlignment
) -> CGRect {
    let scale = max(
        destination.width / CGFloat(image.width),
        destination.height / CGFloat(image.height)
    )
    let size = CGSize(
        width: CGFloat(image.width) * scale,
        height: CGFloat(image.height) * scale
    )
    let x = destination.midX - size.width / 2
    let y: CGFloat
    switch verticalAlignment {
    case .center: y = destination.midY - size.height / 2
    case .top: y = destination.maxY - size.height
    }
    return CGRect(origin: CGPoint(x: x, y: y), size: size)
}

private func drawAspectFill(
    _ image: CGImage,
    in destination: CGRect,
    context: CGContext,
    verticalAlignment: VerticalAlignment = .center
) {
    context.saveGState()
    context.clip(to: destination)
    context.interpolationQuality = .high
    context.draw(
        image,
        in: aspectFillRect(
            image: image,
            destination: destination,
            verticalAlignment: verticalAlignment
        )
    )
    context.restoreGState()
}

private let ciContext = CIContext(options: [
    .workingColorSpace: sRGB,
    .outputColorSpace: sRGB,
    .cacheIntermediates: false,
])

private func blurredAspectFill(_ image: CGImage, size: CGSize, radius: CGFloat) -> CGImage? {
    let source = CIImage(cgImage: image)
    let scale = max(size.width / source.extent.width, size.height / source.extent.height)
    let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let cropX = scaled.extent.midX - size.width / 2
    let cropY = scaled.extent.midY - size.height / 2
    let crop = CGRect(x: cropX, y: cropY, width: size.width, height: size.height)
    let positioned = scaled
        .cropped(to: crop)
        .transformed(by: CGAffineTransform(translationX: -cropX, y: -cropY))
    let outputRect = CGRect(origin: .zero, size: size)
    let blurred = positioned
        .clampedToExtent()
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
        .cropped(to: outputRect)
    return ciContext.createCGImage(
        blurred,
        from: outputRect,
        format: .RGBA8,
        colorSpace: sRGB
    )
}

private func drawRadialGlow(
    on canvas: RasterCanvas,
    center: CGPoint,
    radius: CGFloat,
    color: RGBA,
    alpha: CGFloat
) {
    guard let gradient = CGGradient(
        colorsSpace: sRGB,
        colors: [color.opacity(alpha).cgColor, color.opacity(0).cgColor] as CFArray,
        locations: [0, 1]
    ) else { return }
    canvas.context.saveGState()
    canvas.context.setBlendMode(.screen)
    canvas.context.drawRadialGradient(
        gradient,
        startCenter: canvas.quartzPoint(center),
        startRadius: 0,
        endCenter: canvas.quartzPoint(center),
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
    canvas.context.restoreGState()
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func unit() -> CGFloat {
        CGFloat(Double(next() >> 11) / Double(1 << 53))
    }
}

private func drawArrowHead(
    context: CGContext,
    from: CGPoint,
    to: CGPoint,
    length: CGFloat,
    width: CGFloat
) {
    let dx = to.x - from.x
    let dy = to.y - from.y
    let magnitude = max(0.001, sqrt(dx * dx + dy * dy))
    let ux = dx / magnitude
    let uy = dy / magnitude
    let normal = CGPoint(x: -uy, y: ux)
    let base = CGPoint(x: to.x - ux * length, y: to.y - uy * length)
    let path = CGMutablePath()
    path.move(to: to)
    path.addLine(to: CGPoint(x: base.x + normal.x * width, y: base.y + normal.y * width))
    path.addLine(to: CGPoint(x: base.x - normal.x * width, y: base.y - normal.y * width))
    path.closeSubpath()
    context.addPath(path)
    context.fillPath()
}

private func drawMazeMotif(on canvas: RasterCanvas, seed: UInt64) {
    var rng = SplitMix64(seed: seed)
    let context = canvas.context
    let w = CGFloat(canvas.width)
    let h = CGFloat(canvas.height)
    let scale = w / 1320

    context.saveGState()
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(12 * scale)

    for index in 0..<18 {
        var topPoint = CGPoint(
            x: -100 + rng.unit() * (w + 200),
            y: 620 + rng.unit() * (h - 480)
        )
        let path = CGMutablePath()
        path.move(to: canvas.quartzPoint(topPoint))
        var previous = topPoint
        let segmentCount = 2 + Int(rng.next() % 4)
        for segment in 0..<segmentCount {
            let distance = (110 + rng.unit() * 260) * scale
            if (index + segment) % 2 == 0 {
                topPoint.x += rng.next().isMultiple(of: 2) ? distance : -distance
            } else {
                topPoint.y += rng.next().isMultiple(of: 2) ? distance : -distance
            }
            topPoint.x = min(w + 120, max(-120, topPoint.x))
            topPoint.y = min(h + 120, max(560, topPoint.y))
            path.addLine(to: canvas.quartzPoint(topPoint))
            previous = segment == segmentCount - 1 ? previous : topPoint
        }

        let color = index.isMultiple(of: 4) ? Palette.pink : Palette.cyan
        context.setStrokeColor(color.opacity(index.isMultiple(of: 3) ? 0.075 : 0.045).cgColor)
        context.addPath(path)
        context.strokePath()
        context.setFillColor(color.opacity(0.07).cgColor)
        drawArrowHead(
            context: context,
            from: canvas.quartzPoint(previous),
            to: canvas.quartzPoint(topPoint),
            length: 28 * scale,
            width: 19 * scale
        )
    }
    context.restoreGState()
}

private func drawBackground(
    on canvas: RasterCanvas,
    source: CGImage,
    accent: RGBA,
    seed: UInt64
) {
    let context = canvas.context
    let full = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
    if let gradient = CGGradient(
        colorsSpace: sRGB,
        colors: [Palette.top.cgColor, Palette.middle.cgColor, Palette.bottom.cgColor] as CFArray,
        locations: [0, 0.55, 1]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: canvas.height),
            end: CGPoint(x: 0, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    if let blurred = blurredAspectFill(
        source,
        size: canvas.size,
        radius: max(36, canvas.size.width * 0.035)
    ) {
        context.saveGState()
        context.setAlpha(0.27)
        context.setBlendMode(.screen)
        context.draw(blurred, in: full)
        context.restoreGState()
    }

    context.setFillColor(Palette.bottom.opacity(0.52).cgColor)
    context.fill(full)
    drawRadialGlow(
        on: canvas,
        center: CGPoint(x: canvas.size.width * 0.17, y: canvas.size.height * 0.62),
        radius: canvas.size.width * 0.62,
        color: Palette.cyan,
        alpha: 0.17
    )
    drawRadialGlow(
        on: canvas,
        center: CGPoint(x: canvas.size.width * 0.86, y: canvas.size.height * 0.52),
        radius: canvas.size.width * 0.58,
        color: accent,
        alpha: 0.18
    )
    drawMazeMotif(on: canvas, seed: seed)

    let scrimHeight: CGFloat = canvas.width < 1600 ? 760 : 650
    if let scrim = CGGradient(
        colorsSpace: sRGB,
        colors: [
            Palette.bottom.opacity(0.97).cgColor,
            Palette.middle.opacity(0.84).cgColor,
            Palette.middle.opacity(0).cgColor,
        ] as CFArray,
        locations: [0, 0.63, 1]
    ) {
        context.drawLinearGradient(
            scrim,
            start: CGPoint(x: 0, y: canvas.height),
            end: CGPoint(x: 0, y: canvas.height - Int(scrimHeight)),
            options: []
        )
    }

    if let vignette = CGGradient(
        colorsSpace: sRGB,
        colors: [Palette.bottom.opacity(0).cgColor, Palette.bottom.opacity(0.62).cgColor] as CFArray,
        locations: [0, 1]
    ) {
        context.drawLinearGradient(
            vignette,
            start: CGPoint(x: 0, y: CGFloat(canvas.height) * 0.45),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }
}

private func withRotatedTopLeftObject(
    on canvas: RasterCanvas,
    rect: CGRect,
    clockwiseDegrees: CGFloat,
    drawing: (CGContext, CGRect) -> Void
) {
    let context = canvas.context
    let topCenter = CGPoint(x: rect.midX, y: rect.midY)
    let center = canvas.quartzPoint(topCenter)
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: -clockwiseDegrees * .pi / 180)
    let local = CGRect(
        x: -rect.width / 2,
        y: -rect.height / 2,
        width: rect.width,
        height: rect.height
    )
    drawing(context, local)
    context.restoreGState()
}

private func drawDevice(
    on canvas: RasterCanvas,
    capture: CGImage,
    rect: CGRect,
    rotation: CGFloat,
    kind: DeviceKind,
    glow: RGBA
) {
    withRotatedTopLeftObject(on: canvas, rect: rect, clockwiseDegrees: rotation) { context, outer in
        let radius = kind == .iPhone ? outer.width * 0.125 : outer.width * 0.055
        let outerPath = CGPath(
            roundedRect: outer,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -22),
            blur: kind == .iPhone ? 74 : 90,
            color: glow.opacity(0.44).cgColor
        )
        context.setFillColor(Palette.shell.cgColor)
        context.addPath(outerPath)
        context.fillPath()
        context.restoreGState()

        context.setFillColor(Palette.shell.cgColor)
        context.addPath(outerPath)
        context.fillPath()
        context.setStrokeColor(Palette.ink.opacity(0.30).cgColor)
        context.setLineWidth(kind == .iPhone ? 4 : 3)
        context.addPath(outerPath)
        context.strokePath()

        let horizontalInset = kind == .iPhone ? max(16, outer.width * 0.019) : max(14, outer.width * 0.012)
        let verticalInset = kind == .iPhone ? max(24, outer.width * 0.030) : max(15, outer.width * 0.013)
        let available = outer.insetBy(dx: horizontalInset, dy: verticalInset)
        let aspect = CGFloat(capture.width) / CGFloat(capture.height)
        var screenSize = CGSize(width: available.width, height: available.width / aspect)
        if screenSize.height > available.height {
            screenSize.height = available.height
            screenSize.width = screenSize.height * aspect
        }
        let screen = CGRect(
            x: outer.midX - screenSize.width / 2,
            y: outer.midY - screenSize.height / 2,
            width: screenSize.width,
            height: screenSize.height
        )
        let screenRadius = kind == .iPhone ? screen.width * 0.105 : screen.width * 0.044
        let screenPath = CGPath(
            roundedRect: screen,
            cornerWidth: screenRadius,
            cornerHeight: screenRadius,
            transform: nil
        )
        context.saveGState()
        context.addPath(screenPath)
        context.clip()
        drawAspectFill(capture, in: screen, context: context)
        context.restoreGState()

        context.setStrokeColor(Palette.ink.opacity(0.22).cgColor)
        context.setLineWidth(2)
        context.addPath(screenPath)
        context.strokePath()
    }
}

private func drawPhotoCard(
    on canvas: RasterCanvas,
    photo: CGImage,
    rect: CGRect,
    rotation: CGFloat
) {
    withRotatedTopLeftObject(on: canvas, rect: rect, clockwiseDegrees: rotation) { context, outer in
        let radius = outer.width * 0.105
        let path = CGPath(
            roundedRect: outer,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -24),
            blur: 60,
            color: Palette.pink.opacity(0.42).cgColor
        )
        context.setFillColor(Palette.ink.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        context.setFillColor(Palette.ink.cgColor)
        context.addPath(path)
        context.fillPath()
        let inset = max(10, outer.width * 0.022)
        let imageRect = outer.insetBy(dx: inset, dy: inset)
        let imagePath = CGPath(
            roundedRect: imageRect,
            cornerWidth: radius - inset,
            cornerHeight: radius - inset,
            transform: nil
        )
        context.saveGState()
        context.addPath(imagePath)
        context.clip()
        drawAspectFill(photo, in: imageRect, context: context)
        context.restoreGState()
        context.setStrokeColor(Palette.ink.opacity(0.92).cgColor)
        context.setLineWidth(3)
        context.addPath(path)
        context.strokePath()
    }
}

private func drawCaptureCard(
    on canvas: RasterCanvas,
    capture: CGImage,
    rect: CGRect,
    rotation: CGFloat,
    glow: RGBA
) {
    withRotatedTopLeftObject(on: canvas, rect: rect, clockwiseDegrees: rotation) { context, outer in
        let radius = outer.width * 0.085
        let path = CGPath(
            roundedRect: outer,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -22),
            blur: 70,
            color: glow.opacity(0.48).cgColor
        )
        context.setFillColor(Palette.shell.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
        context.setFillColor(Palette.shell.cgColor)
        context.addPath(path)
        context.fillPath()

        let inset = max(12, outer.width * 0.018)
        let inner = outer.insetBy(dx: inset, dy: inset)
        let innerPath = CGPath(
            roundedRect: inner,
            cornerWidth: radius - inset,
            cornerHeight: radius - inset,
            transform: nil
        )
        context.saveGState()
        context.addPath(innerPath)
        context.clip()
        drawAspectFill(capture, in: inner, context: context, verticalAlignment: .top)
        context.restoreGState()

        context.setStrokeColor(Palette.ink.opacity(0.34).cgColor)
        context.setLineWidth(3)
        context.addPath(path)
        context.strokePath()
    }
}

private func drawCurvedMarketingArrow(
    on canvas: RasterCanvas,
    start: CGPoint,
    control1: CGPoint,
    control2: CGPoint,
    end: CGPoint,
    accent: RGBA
) {
    let context = canvas.context
    let isPhoneCanvas = canvas.width < 1600
    let glowWidth: CGFloat = isPhoneCanvas ? 42 : 54
    let outlineWidth: CGFloat = isPhoneCanvas ? 29 : 39
    let coreWidth: CGFloat = isPhoneCanvas ? 17 : 23
    let headLength: CGFloat = isPhoneCanvas ? 76 : 96
    let headWidth: CGFloat = isPhoneCanvas ? 45 : 58
    let shadowInk = RGBA(0x050317)
    let path = CGMutablePath()
    path.move(to: canvas.quartzPoint(start))
    path.addCurve(
        to: canvas.quartzPoint(end),
        control1: canvas.quartzPoint(control1),
        control2: canvas.quartzPoint(control2)
    )

    // Keep the cyan transformation glow, then add a soft navy backplate.
    // The dark edge makes the arrow readable where it crosses the bright
    // photo card without turning the white core into a heavy outlined icon.
    context.saveGState()
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setShadow(offset: .zero, blur: 46, color: accent.opacity(0.78).cgColor)
    context.setStrokeColor(accent.opacity(0.42).cgColor)
    context.setLineWidth(glowWidth)
    context.addPath(path)
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setShadow(
        offset: CGSize(width: 4, height: -8),
        blur: isPhoneCanvas ? 22 : 28,
        color: shadowInk.opacity(0.86).cgColor
    )
    context.setStrokeColor(shadowInk.opacity(0.88).cgColor)
    context.setLineWidth(outlineWidth)
    context.addPath(path)
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setShadow(offset: .zero, blur: 18, color: accent.opacity(0.9).cgColor)
    context.setStrokeColor(Palette.ink.cgColor)
    context.setLineWidth(coreWidth)
    context.addPath(path)
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 4, height: -8),
        blur: isPhoneCanvas ? 22 : 28,
        color: shadowInk.opacity(0.88).cgColor
    )
    context.setFillColor(shadowInk.opacity(0.96).cgColor)
    drawArrowHead(
        context: context,
        from: canvas.quartzPoint(control2),
        to: canvas.quartzPoint(end),
        length: headLength + (isPhoneCanvas ? 11 : 14),
        width: headWidth + (isPhoneCanvas ? 8 : 10)
    )
    context.restoreGState()

    context.saveGState()
    context.setShadow(offset: .zero, blur: 16, color: accent.opacity(0.88).cgColor)
    context.setFillColor(Palette.ink.cgColor)
    drawArrowHead(
        context: context,
        from: canvas.quartzPoint(control2),
        to: canvas.quartzPoint(end),
        length: headLength,
        width: headWidth
    )
    context.restoreGState()
}

private func drawSparkles(
    on canvas: RasterCanvas,
    seed: UInt64,
    colors: [RGBA],
    count: Int
) {
    var rng = SplitMix64(seed: seed)
    let context = canvas.context
    let w = CGFloat(canvas.width)
    let h = CGFloat(canvas.height)
    let scale = w / 1320
    context.saveGState()
    for index in 0..<count {
        let topPoint = CGPoint(
            x: 45 + rng.unit() * (w - 90),
            y: 680 + rng.unit() * (h - 790)
        )
        let point = canvas.quartzPoint(topPoint)
        let radius = (5 + rng.unit() * 13) * scale
        let color = colors[index % colors.count]
        context.setFillColor(color.opacity(0.58 + rng.unit() * 0.3).cgColor)
        if index.isMultiple(of: 3) {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: point.x, y: point.y + radius * 1.8))
            path.addLine(to: CGPoint(x: point.x + radius, y: point.y))
            path.addLine(to: CGPoint(x: point.x, y: point.y - radius * 1.8))
            path.addLine(to: CGPoint(x: point.x - radius, y: point.y))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        } else {
            context.fillEllipse(in: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
    }
    context.restoreGState()
}

// MARK: - Slide layouts

private func drawTemplate(
    slide: Slide,
    device: DeviceKind,
    canvas: RasterCanvas,
    captures: [String: LoadedImage],
    photo: CGImage
) throws {
    guard let primary = captures[slide.backgroundCapture]?.image else {
        throw ScriptError.message("Missing primary capture for \(slide.id).")
    }
    switch slide.template {
    case "photoToMaze":
        if device == .iPhone {
            drawPhotoCard(
                on: canvas,
                photo: photo,
                rect: CGRect(x: 42, y: 760, width: 510, height: 638),
                rotation: -6
            )
            drawDevice(
                on: canvas,
                capture: primary,
                rect: CGRect(x: 520, y: 865, width: 850, height: 1847),
                rotation: 4,
                kind: device,
                glow: Palette.pink
            )
            // The transformation arrow intentionally sits above both cards:
            // its head remains obvious at App Store thumbnail size and lands
            // inside the real generated level rather than disappearing under
            // the device bezel.
            drawCurvedMarketingArrow(
                on: canvas,
                start: CGPoint(x: 470, y: 1135),
                control1: CGPoint(x: 575, y: 1100),
                control2: CGPoint(x: 620, y: 1250),
                end: CGPoint(x: 720, y: 1320),
                accent: Palette.cyan
            )
        } else {
            drawPhotoCard(
                on: canvas,
                photo: photo,
                rect: CGRect(x: 100, y: 735, width: 720, height: 900),
                rotation: -4
            )
            drawDevice(
                on: canvas,
                capture: primary,
                rect: CGRect(x: 820, y: 650, width: 1320, height: 1760),
                rotation: 2,
                kind: device,
                glow: Palette.pink
            )
            drawCurvedMarketingArrow(
                on: canvas,
                start: CGPoint(x: 740, y: 1260),
                control1: CGPoint(x: 890, y: 1170),
                control2: CGPoint(x: 930, y: 1320),
                end: CGPoint(x: 1080, y: 1370),
                accent: Palette.cyan
            )
        }

    case "heroDevice":
        drawRadialGlow(
            on: canvas,
            center: CGPoint(x: canvas.size.width * 0.5, y: canvas.size.height * 0.60),
            radius: canvas.size.width * 0.48,
            color: Palette.cyan,
            alpha: 0.26
        )
        let rect = device == .iPhone
            ? CGRect(x: 170, y: 690, width: 980, height: 2129)
            : CGRect(x: 245, y: 620, width: 1574, height: 2099)
        drawDevice(
            on: canvas,
            capture: primary,
            rect: rect,
            rotation: device == .iPhone ? -1.5 : 0,
            kind: device,
            glow: Palette.cyan
        )

    case "combo":
        drawSparkles(
            on: canvas,
            seed: device == .iPhone ? 0xC0AB01 : 0xC0AB02,
            colors: [Palette.gold, Palette.cyan, Palette.pink, Palette.success],
            count: device == .iPhone ? 24 : 34
        )
        let rect = device == .iPhone
            ? CGRect(x: 130, y: 690, width: 1060, height: 2304)
            : CGRect(x: 220, y: 610, width: 1624, height: 2165)
        drawDevice(
            on: canvas,
            capture: primary,
            rect: rect,
            rotation: device == .iPhone ? 1.5 : 0,
            kind: device,
            glow: Palette.gold
        )
        drawSparkles(
            on: canvas,
            seed: device == .iPhone ? 0xC0AB11 : 0xC0AB12,
            colors: [Palette.gold, Palette.ink, Palette.pink],
            count: device == .iPhone ? 12 : 18
        )

    case "worlds":
        drawRadialGlow(
            on: canvas,
            center: CGPoint(x: canvas.size.width * 0.18, y: canvas.size.height * 0.48),
            radius: canvas.size.width * 0.33,
            color: Palette.success,
            alpha: 0.22
        )
        drawRadialGlow(
            on: canvas,
            center: CGPoint(x: canvas.size.width * 0.82, y: canvas.size.height * 0.72),
            radius: canvas.size.width * 0.35,
            color: Palette.pink,
            alpha: 0.23
        )
        let rect = device == .iPhone
            ? CGRect(x: 205, y: 700, width: 910, height: 1977)
            : CGRect(x: 245, y: 620, width: 1574, height: 2099)
        drawDevice(
            on: canvas,
            capture: primary,
            rect: rect,
            rotation: 0,
            kind: device,
            glow: Palette.pink
        )

    case "dailyAndQuests":
        guard let quests = captures["quests"]?.image else {
            throw ScriptError.message("Missing quests capture for the Daily slide.")
        }
        if device == .iPhone {
            drawDevice(
                on: canvas,
                capture: primary,
                rect: CGRect(x: 78, y: 710, width: 840, height: 1825),
                rotation: -2,
                kind: device,
                glow: Palette.cyan
            )
            drawCaptureCard(
                on: canvas,
                capture: quests,
                rect: CGRect(x: 650, y: 1480, width: 610, height: 790),
                rotation: 3,
                glow: Palette.gold
            )
        } else {
            drawDevice(
                on: canvas,
                capture: primary,
                rect: CGRect(x: 80, y: 690, width: 1280, height: 1707),
                rotation: -1,
                kind: device,
                glow: Palette.cyan
            )
            drawCaptureCard(
                on: canvas,
                capture: quests,
                rect: CGRect(x: 1180, y: 1020, width: 800, height: 1100),
                rotation: 2,
                glow: Palette.gold
            )
        }

    default:
        throw ScriptError.message("Unknown template: \(slide.template)")
    }
}

private func renderSlide(
    slide: Slide,
    index: Int,
    locale: String,
    device: DeviceKind,
    captures: [String: LoadedImage],
    photo: CGImage
) throws -> CGImage {
    guard let background = captures[slide.backgroundCapture]?.image else {
        throw ScriptError.message("Missing background capture \(slide.backgroundCapture).")
    }
    let canvas = try RasterCanvas(size: device.pixelSize)
    drawBackground(
        on: canvas,
        source: slide.template == "photoToMaze" ? photo : background,
        accent: Palette.accent(named: slide.accent),
        seed: UInt64(0xA220_0000 + index * 131 + (device == .iPhone ? 1 : 2))
    )
    try drawTemplate(
        slide: slide,
        device: device,
        canvas: canvas,
        captures: captures,
        photo: photo
    )
    try drawCopy(slide: slide, locale: locale, device: device, canvas: canvas)
    return try canvas.makeImage()
}

// MARK: - Contact sheet

private func drawRoundedThumbnail(
    image: CGImage,
    topRect: CGRect,
    radius: CGFloat,
    on canvas: RasterCanvas,
    shadow: RGBA
) {
    let rect = canvas.quartzRect(topRect)
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )
    let context = canvas.context
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: shadow.opacity(0.4).cgColor)
    context.setFillColor(Palette.shell.cgColor)
    context.addPath(path)
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(path)
    context.clip()
    drawAspectFill(image, in: rect, context: context)
    context.restoreGState()
    context.setStrokeColor(Palette.ink.opacity(0.20).cgColor)
    context.setLineWidth(2)
    context.addPath(path)
    context.strokePath()
}

private func renderContactSheet(
    manifest: Manifest,
    outputRoot: URL,
    destination: URL
) throws {
    let canvas = try RasterCanvas(size: CGSize(width: 2400, height: 1500))
    let context = canvas.context
    if let gradient = CGGradient(
        colorsSpace: sRGB,
        colors: [Palette.top.cgColor, Palette.bottom.cgColor] as CFArray,
        locations: [0, 1]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: canvas.height),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }
    drawTextLine(
        on: canvas,
        text: "\(manifest.locale.uppercased()) · APP STORE SCREENSHOTS",
        top: 34,
        size: 48,
        weight: .heavy,
        color: Palette.ink,
        tracking: 1,
        shadow: true,
        locale: manifest.locale
    )
    drawTextLine(
        on: canvas,
        text: "iPhone 6.9\"",
        top: 102,
        size: 30,
        weight: .semibold,
        color: Palette.cyan,
        tracking: 0,
        shadow: false
    )
    drawTextLine(
        on: canvas,
        text: "iPad 13\"",
        top: 793,
        size: 30,
        weight: .semibold,
        color: Palette.pink,
        tracking: 0,
        shadow: false
    )

    let margin: CGFloat = 80
    let gap: CGFloat = 24
    let columnWidth = (CGFloat(canvas.width) - margin * 2 - gap * 4) / 5
    for (index, slide) in manifest.slides.enumerated() {
        let columnX = margin + CGFloat(index) * (columnWidth + gap)
        let phoneURL = outputRoot
            .appendingPathComponent(DeviceKind.iPhone.rawValue)
            .appendingPathComponent(slide.filename)
        let padURL = outputRoot
            .appendingPathComponent(DeviceKind.iPad.rawValue)
            .appendingPathComponent(slide.filename)
        let phone = try loadImage(at: phoneURL).image
        let pad = try loadImage(at: padURL).image

        let phoneHeight: CGFloat = 555
        let phoneWidth = phoneHeight * CGFloat(phone.width) / CGFloat(phone.height)
        drawRoundedThumbnail(
            image: phone,
            topRect: CGRect(
                x: columnX + (columnWidth - phoneWidth) / 2,
                y: 160,
                width: phoneWidth,
                height: phoneHeight
            ),
            radius: 24,
            on: canvas,
            shadow: Palette.cyan
        )
        drawTextLine(
            on: canvas,
            text: String(index + 1),
            top: 727,
            size: 27,
            weight: .heavy,
            color: Palette.inkSoft,
            tracking: 0,
            shadow: false,
            centerX: columnX + columnWidth / 2
        )

        let padHeight: CGFloat = 540
        let padWidth = padHeight * CGFloat(pad.width) / CGFloat(pad.height)
        drawRoundedThumbnail(
            image: pad,
            topRect: CGRect(
                x: columnX + (columnWidth - padWidth) / 2,
                y: 850,
                width: padWidth,
                height: padHeight
            ),
            radius: 20,
            on: canvas,
            shadow: Palette.pink
        )
    }
    try writePNG(try canvas.makeImage(), to: destination)
}

// MARK: - Validation

private struct PNGInfo {
    let width: Int
    let height: Int
    let hasAlpha: Bool
    let colorModel: String
    let colorSpaceName: String
}

private func inspectPNG(_ url: URL) throws -> PNGInfo {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ScriptError.message("Unable to inspect output: \(url.path)")
    }
    let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? image.width
    let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? image.height
    let hasAlpha = (properties[kCGImagePropertyHasAlpha] as? NSNumber)?.boolValue ?? {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
    }()
    let model = (properties[kCGImagePropertyColorModel] as? String) ?? "unknown"
    let colorSpaceName = image.colorSpace?.name as String? ?? "unknown"
    return PNGInfo(
        width: width,
        height: height,
        hasAlpha: hasAlpha,
        colorModel: model,
        colorSpaceName: colorSpaceName
    )
}

private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func validateOutputs(options: Options, manifest: Manifest) throws {
    var problems: [String] = []
    var seenHashes: [String: String] = [:]

    for device in DeviceKind.allCases {
        let folder = options.outputRoot.appendingPathComponent(device.rawValue, isDirectory: true)
        let expectedNames = Set(manifest.slides.map(\.filename))
        let actualNames: Set<String>
        do {
            actualNames = Set(
                try FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: nil
                )
                .filter { $0.pathExtension.lowercased() == "png" }
                .map(\.lastPathComponent)
            )
        } catch {
            problems.append("Missing output directory: \(folder.path)")
            continue
        }
        if actualNames != expectedNames {
            let missing = expectedNames.subtracting(actualNames).sorted()
            let extra = actualNames.subtracting(expectedNames).sorted()
            if !missing.isEmpty { problems.append("\(device.rawValue) missing files: \(missing)") }
            if !extra.isEmpty { problems.append("\(device.rawValue) unexpected PNGs: \(extra)") }
        }

        for slide in manifest.slides {
            let url = folder.appendingPathComponent(slide.filename)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let info = try inspectPNG(url)
                let expected = device.pixelSize
                if info.width != Int(expected.width) || info.height != Int(expected.height) {
                    problems.append("\(url.path) is \(info.width)x\(info.height), expected \(Int(expected.width))x\(Int(expected.height)).")
                }
                if info.hasAlpha { problems.append("\(url.path) contains an alpha channel.") }
                if info.colorModel.uppercased() != "RGB" {
                    problems.append("\(url.path) color model is \(info.colorModel), expected RGB.")
                }
                if !info.colorSpaceName.lowercased().contains("srgb") {
                    problems.append("\(url.path) color space is \(info.colorSpaceName), expected sRGB.")
                }
                let hash = sha256(try Data(contentsOf: url))
                if let other = seenHashes[hash] {
                    problems.append("Duplicate final files: \(other) and \(url.path)")
                } else {
                    seenHashes[hash] = url.path
                }
            } catch {
                problems.append(String(describing: error))
            }
        }
    }

    if !FileManager.default.fileExists(atPath: options.contactSheet.path) {
        problems.append("Missing contact sheet: \(options.contactSheet.path)")
    } else {
        do {
            let info = try inspectPNG(options.contactSheet)
            if info.width != 2400 || info.height != 1500 {
                problems.append("Contact sheet must be 2400x1500, found \(info.width)x\(info.height).")
            }
            if info.hasAlpha { problems.append("Contact sheet contains an alpha channel.") }
            if info.colorModel.uppercased() != "RGB" || !info.colorSpaceName.lowercased().contains("srgb") {
                problems.append("Contact sheet must be RGB/sRGB.")
            }
        } catch {
            problems.append(String(describing: error))
        }
    }

    if !problems.isEmpty {
        throw ScriptError.problems(["Screenshot validation failed:"] + problems.map { "  - \($0)" })
    }
    print(
        "Validation passed for \(manifest.locale): 10 App Store PNGs are " +
        "exact-size RGB/sRGB without alpha."
    )
}

// MARK: - Command line

private func absoluteURL(_ value: String) -> URL {
    if value.hasPrefix("/") { return URL(fileURLWithPath: value).standardizedFileURL }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(value)
        .standardizedFileURL
}

private func parseOptions() throws -> Options {
    var options = Options()
    let arguments = Array(CommandLine.arguments.dropFirst())
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--validate":
            options.validateOnly = true
        case "--locale":
            guard index + 1 < arguments.count else {
                throw ScriptError.message("Missing value after \(argument).")
            }
            index += 1
            options.locale = arguments[index]
            options.localeWasExplicit = true
        case "--input-root", "--output-root", "--manifest", "--photo", "--contact-sheet":
            guard index + 1 < arguments.count else {
                throw ScriptError.message("Missing value after \(argument).")
            }
            index += 1
            let url = absoluteURL(arguments[index])
            switch argument {
            case "--input-root":
                options.inputRoot = url
                options.inputRootWasExplicit = true
            case "--output-root":
                options.outputRoot = url
                options.outputRootWasExplicit = true
            case "--manifest":
                options.manifest = url
                options.manifestWasExplicit = true
            case "--photo": options.photo = url
            case "--contact-sheet":
                options.contactSheet = url
                options.contactSheetWasExplicit = true
            default: break
            }
        case "--help", "-h":
            print("""
            Render localized Arrow Maze App Store screenshots.

            Usage:
              swift render_english_screenshots.swift [options]

            Options:
              --validate              Validate existing outputs only
              --locale LOCALE         Storefront locale (default: en-US)
              --input-root PATH       Capture root containing device folders
              --output-root PATH      Generated output root
              --manifest PATH         Localized JSON manifest
              --photo PATH            Shared Photo Maze source image
              --contact-sheet PATH    Review contact-sheet output
            """)
            exit(EXIT_SUCCESS)
        default:
            throw ScriptError.message("Unknown argument: \(argument). Use --help.")
        }
        index += 1
    }

    if options.localeWasExplicit && captureLocaleByStorefront[options.locale] == nil {
        let locales = captureLocaleByStorefront.keys.sorted().joined(separator: ", ")
        throw ScriptError.message(
            "Unsupported storefront locale \(options.locale). Expected one of: \(locales)."
        )
    }
    if !options.manifestWasExplicit {
        options.manifest = sourceDirectory
            .appendingPathComponent("screenshots.\(options.locale).json")
    }
    return options
}

private func resolveLocalePaths(_ parsed: Options, manifest: Manifest) throws -> Options {
    if parsed.localeWasExplicit && parsed.locale != manifest.locale {
        throw ScriptError.message(
            "--locale \(parsed.locale) does not match manifest locale \(manifest.locale)."
        )
    }

    var options = parsed
    options.locale = manifest.locale
    if !options.inputRootWasExplicit {
        options.inputRoot = sourceDirectory
            .appendingPathComponent("_captures", isDirectory: true)
            .appendingPathComponent(manifest.captureLocale, isDirectory: true)
    }
    if !options.outputRootWasExplicit {
        options.outputRoot = sourceDirectory
            .appendingPathComponent("Generated", isDirectory: true)
            .appendingPathComponent(manifest.locale, isDirectory: true)
    }
    if !options.contactSheetWasExplicit {
        options.contactSheet = sourceDirectory
            .appendingPathComponent("Review/\(manifest.locale)_contact-sheet.png")
    }
    return options
}

private func run() throws {
    let parsedOptions = try parseOptions()
    let manifest = try loadManifest(at: parsedOptions.manifest)
    try validateManifest(manifest)
    let options = try resolveLocalePaths(parsedOptions, manifest: manifest)
    try prepareFonts()
    try validateGlyphCoverage(manifest)

    if options.validateOnly {
        try validateOutputs(options: options, manifest: manifest)
        return
    }

    // Validate every input before creating output directories. This prevents
    // a partial or fake App Store set when even one native capture is absent.
    let captures = try validateInputs(options: options, manifest: manifest)
    let photo = try loadImage(at: options.photo).image

    for device in DeviceKind.allCases {
        guard let deviceCaptures = captures[device] else {
            throw ScriptError.message("Capture map is missing \(device.rawValue).")
        }
        let folder = options.outputRoot.appendingPathComponent(device.rawValue, isDirectory: true)
        for (index, slide) in manifest.slides.enumerated() {
            let image = try renderSlide(
                slide: slide,
                index: index,
                locale: manifest.locale,
                device: device,
                captures: deviceCaptures,
                photo: photo
            )
            let url = folder.appendingPathComponent(slide.filename)
            try writePNG(image, to: url)
            print("Rendered \(device.rawValue)/\(slide.filename)")
        }
    }

    try renderContactSheet(
        manifest: manifest,
        outputRoot: options.outputRoot,
        destination: options.contactSheet
    )
    print("Rendered \(options.contactSheet.path)")
    try validateOutputs(options: options, manifest: manifest)
}

do {
    try run()
} catch {
    fputs("ERROR: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
