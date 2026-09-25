// Lightweight host-side QA renderer. The final App Store capture still uses
// GameScene; this preview only makes silhouette and source-color regressions
// obvious without launching Simulator.

import CoreGraphics
import Foundation
import ImageIO

@main
private struct ParrotFixturePreviewRenderer {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            throw PreviewError("usage: render_parrot_fixture_preview <level.json> <preview.png>")
        }

        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let level = try JSONDecoder().decode(Level.self, from: Data(contentsOf: inputURL))
        let cellSize = 10
        let pixelWidth = level.width * cellSize
        let pixelHeight = level.height * cellSize
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw PreviewError("could not create bitmap context")
        }

        context.setFillColor(CGColor(
            colorSpace: colorSpace,
            components: [0.035, 0.027, 0.105, 1]
        )!)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(CGFloat(cellSize) * 0.68)

        func center(of cell: GridPoint) -> CGPoint {
            CGPoint(
                x: (CGFloat(cell.x) + 0.5) * CGFloat(cellSize),
                y: CGFloat(pixelHeight) - (CGFloat(cell.y) + 0.5) * CGFloat(cellSize)
            )
        }

        for piece in level.pieces {
            guard let first = piece.cells.first else { continue }
            let colorIndex = max(0, min(level.piecePalette.count - 1, (piece.colorGroup ?? 1) - 1))
            let color = level.piecePalette[colorIndex]
            let cgColor = CGColor(
                colorSpace: colorSpace,
                components: [color.red, color.green, color.blue, 1]
            )!

            let path = CGMutablePath()
            path.move(to: center(of: first))
            for cell in piece.cells.dropFirst() {
                path.addLine(to: center(of: cell))
            }
            context.setStrokeColor(cgColor)
            context.addPath(path)
            context.strokePath()

            let head = center(of: piece.headCell)
            let vector: CGPoint
            switch piece.direction {
            case .up: vector = CGPoint(x: 0, y: 1)
            case .down: vector = CGPoint(x: 0, y: -1)
            case .left: vector = CGPoint(x: -1, y: 0)
            case .right: vector = CGPoint(x: 1, y: 0)
            }
            let perpendicular = CGPoint(x: -vector.y, y: vector.x)
            let tipDistance = CGFloat(cellSize) * 0.46
            let baseDistance = CGFloat(cellSize) * 0.30
            let halfBase = CGFloat(cellSize) * 0.38
            let arrowhead = CGMutablePath()
            arrowhead.move(to: CGPoint(
                x: head.x + vector.x * tipDistance,
                y: head.y + vector.y * tipDistance
            ))
            arrowhead.addLine(to: CGPoint(
                x: head.x - vector.x * baseDistance + perpendicular.x * halfBase,
                y: head.y - vector.y * baseDistance + perpendicular.y * halfBase
            ))
            arrowhead.addLine(to: CGPoint(
                x: head.x - vector.x * baseDistance - perpendicular.x * halfBase,
                y: head.y - vector.y * baseDistance - perpendicular.y * halfBase
            ))
            arrowhead.closeSubpath()
            context.setFillColor(cgColor)
            context.addPath(arrowhead)
            context.fillPath()
        }

        guard let image = context.makeImage() else {
            throw PreviewError("could not make preview image")
        }
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw PreviewError("could not create PNG destination")
        }
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
            kCGImagePropertyDepth: 8
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw PreviewError("could not finalize PNG")
        }
        print("preview=\(outputURL.path) size=\(pixelWidth)x\(pixelHeight)")
    }

    private struct PreviewError: Error, CustomStringConvertible {
        let description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
