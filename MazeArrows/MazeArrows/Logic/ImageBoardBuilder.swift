//
//  ImageBoardBuilder.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Turns a user photo into a playable board mask: downsample to the grid,
//  split subject from background by luminance (Otsu threshold, alpha-aware),
//  then cluster the subject cells into adaptive color zones. The zones feed the
//  multi-zone snake-fill generator, giving a Mickey-silhouette-style level
//  where each color region is its own arrow color.
//

import Foundation
import CoreGraphics

nonisolated struct ImageBoardResult: Sendable {
    let width: Int
    let height: Int
    /// Cell sets per color zone, ordered dark → light.
    let zones: [Set<GridPoint>]
    /// Average source color per zone (0...1 RGB) — for preview and tinting.
    let zoneColors: [(r: Double, g: Double, b: Double)]

    var allCells: Set<GridPoint> { zones.reduce(into: Set()) { $0.formUnion($1) } }
}

nonisolated enum ImageBoardBuilder {

    /// - Parameters:
    ///   - targetHeight: board height in cells; width follows the aspect ratio.
    ///   - invert: keep the LIGHT part of the image instead of the dark part.
    ///   - useAlphaMask: treat every opaque cell as subject (for Vision
    ///     cutouts with transparent background) instead of thresholding
    ///     by luminance; `invert` is ignored in this mode.
    static func build(
        from image: CGImage,
        targetHeight: Int,
        invert: Bool,
        useAlphaMask: Bool = false
    ) -> ImageBoardResult? {
        guard !Task.isCancelled else { return nil }
        let requestedHeight = max(8, min(128, targetHeight))
        let aspect = Double(image.width) / Double(max(1, image.height))
        let requestedWidth = max(1, Int((Double(requestedHeight) * aspect).rounded()))
        // Fit both axes together. Previously width stopped at 96 while height
        // kept growing to 128, visibly squeezing square/landscape subjects at
        // the high end of the Detail slider.
        let fitScale = min(1, 128 / Double(requestedWidth))
        let gridH = max(8, Int((Double(requestedHeight) * fitScale).rounded()))
        let gridW = max(6, Int((Double(requestedWidth) * fitScale).rounded()))

        guard let pixels = downsample(image, width: gridW, height: gridH),
              !Task.isCancelled else { return nil }

        // Luminance histogram over opaque cells.
        var luminance = [Double](repeating: 1.0, count: gridW * gridH)
        var opaque = [Bool](repeating: false, count: gridW * gridH)
        for i in 0..<(gridW * gridH) {
            if i.isMultiple(of: 512), Task.isCancelled { return nil }
            let a = pixels[i * 4 + 3]
            guard a >= 128 else { continue }
            opaque[i] = true
            let (r, g, b) = unpremultipliedColor(pixels, pixelIndex: i)
            luminance[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }
        let opaqueLums = (0..<opaque.count).filter { opaque[$0] }.map { luminance[$0] }
        guard opaqueLums.count > 16 else { return nil }
        let threshold = otsuThreshold(opaqueLums)

        // Figure/ground: the side of the threshold that dominates the image
        // border is almost always the BACKGROUND (dark photo backdrop, white
        // paper, etc.) — the subject is the other side. `invert` flips this
        // automatic choice when the heuristic guesses wrong.
        var darkBorder = 0
        var lightBorder = 0
        for y in 0..<gridH {
            guard !Task.isCancelled else { return nil }
            for x in 0..<gridW where y == 0 || y == gridH - 1 || x == 0 || x == gridW - 1 {
                let i = y * gridW + x
                guard opaque[i] else { continue }
                if luminance[i] <= threshold { darkBorder += 1 } else { lightBorder += 1 }
            }
        }
        var subjectIsDark = darkBorder < lightBorder
        if invert { subjectIsDark.toggle() }

        var inside: Set<GridPoint> = []
        for y in 0..<gridH {
            guard !Task.isCancelled else { return nil }
            for x in 0..<gridW {
                let i = y * gridW + x
                guard opaque[i] else { continue }
                let isSubject: Bool
                if useAlphaMask {
                    isSubject = true
                } else {
                    isSubject = subjectIsDark ? luminance[i] <= threshold : luminance[i] > threshold
                }
                if isSubject { inside.insert(GridPoint(x: x, y: y)) }
            }
        }

        // Close pinholes: an empty cell with 3+ subject neighbors joins the
        // mask. Lace-like masks (thin drawings, hair, foliage at high detail)
        // are riddled with 1-cell holes that make the snake generator's job
        // nearly impossible. Higher detail resolves more lace, so the number
        // of closing passes scales with the grid.
        let closingPasses = max(2, gridH / 12)
        for _ in 0..<closingPasses {
            guard !Task.isCancelled else { return nil }
            var additions: [GridPoint] = []
            for y in 0..<gridH {
                guard !Task.isCancelled else { return nil }
                for x in 0..<gridW {
                    let cell = GridPoint(x: x, y: y)
                    guard !inside.contains(cell) else { continue }
                    var neighbors = 0
                    if inside.contains(GridPoint(x: x + 1, y: y)) { neighbors += 1 }
                    if inside.contains(GridPoint(x: x - 1, y: y)) { neighbors += 1 }
                    if inside.contains(GridPoint(x: x, y: y + 1)) { neighbors += 1 }
                    if inside.contains(GridPoint(x: x, y: y - 1)) { neighbors += 1 }
                    if neighbors >= 3 { additions.append(cell) }
                }
            }
            if additions.isEmpty { break }
            inside.formUnion(additions)
        }

        // Cells with no orthogonal neighbor can never join a ≥2-cell arrow —
        // they would make generation fail outright. Peel them off.
        removeIsolatedCells(&inside)
        guard !Task.isCancelled, inside.count >= 24 else { return nil }

        // Split the subject into adaptive color zones. Clusters whose
        // average colors read as the same color merge back together, so the
        // zone count follows the photo itself: a flat silhouette stays one
        // color, a two-tone subject gets two.
        let clusterCount = min(6, max(3, inside.count / 120))
        guard var (assignment, centers) = kMeans(
            cells: inside,
            k: clusterCount,
            pixels: pixels,
            gridW: gridW
        ) else { return nil }
        mergeSimilarZones(&assignment, centers: &centers)
        guard !Task.isCancelled else { return nil }

        // Zone-local isolated cells also break generation — reassign them to
        // an adjacent zone (they stay inside the silhouette).
        healZoneIslands(&assignment)
        guard !Task.isCancelled else { return nil }

        // Small connected components (speckles stranded in a zone or floating
        // in the mask) can't be snake-partitioned — or produce cramped zones
        // that make orientation nearly impossible. Reattach them to a
        // neighboring zone when one touches, otherwise drop them.
        cleanupSmallComponents(&assignment, minSize: 9)
        guard !Task.isCancelled else { return nil }

        var zoneCells: [[GridPoint]] = Array(repeating: [], count: centers.count)
        for (cell, zone) in assignment {
            guard !Task.isCancelled else { return nil }
            zoneCells[zone].append(cell)
        }

        // Merge dwarf zones into the largest zone.
        let biggest = zoneCells.indices.max { zoneCells[$0].count < zoneCells[$1].count } ?? 0
        for index in zoneCells.indices where index != biggest && zoneCells[index].count < 12 {
            zoneCells[biggest].append(contentsOf: zoneCells[index])
            zoneCells[index] = []
        }

        var zones: [Set<GridPoint>] = []
        var zoneColors: [(r: Double, g: Double, b: Double)] = []
        for cells in zoneCells where !cells.isEmpty {
            guard !Task.isCancelled else { return nil }
            var set = Set(cells)
            removeIsolatedCells(&set)
            guard set.count >= 4 else { continue }
            zones.append(set)
            zoneColors.append(averageColor(of: Array(set), pixels: pixels, gridW: gridW))
        }
        guard !zones.isEmpty else { return nil }

        // Dark zones first so zone 0 reads as the "main" silhouette color.
        let order = zones.indices.sorted {
            lum(zoneColors[$0]) < lum(zoneColors[$1])
        }
        return ImageBoardResult(
            width: gridW,
            height: gridH,
            zones: order.map { zones[$0] },
            zoneColors: order.map { zoneColors[$0] }
        )
    }

    // MARK: - helpers

    private static func lum(_ c: (r: Double, g: Double, b: Double)) -> Double {
        0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    /// Vision cutouts use premultiplied alpha. Undo that multiplication before
    /// measuring hue, otherwise antialiased edges are recorded as dark/brown.
    private static func unpremultipliedColor(
        _ pixels: [UInt8],
        pixelIndex: Int
    ) -> (r: Double, g: Double, b: Double) {
        let offset = pixelIndex * 4
        let alpha = max(1 / 255, Double(pixels[offset + 3]) / 255)
        return (
            r: min(1, Double(pixels[offset]) / 255 / alpha),
            g: min(1, Double(pixels[offset + 1]) / 255 / alpha),
            b: min(1, Double(pixels[offset + 2]) / 255 / alpha)
        )
    }

    private static func averageColor(
        of cells: [GridPoint],
        pixels: [UInt8],
        gridW: Int
    ) -> (r: Double, g: Double, b: Double) {
        guard !cells.isEmpty else { return (0, 0, 0) }
        var r = 0.0
        var g = 0.0
        var b = 0.0
        for cell in cells {
            let color = unpremultipliedColor(
                pixels,
                pixelIndex: cell.y * gridW + cell.x
            )
            r += color.r
            g += color.g
            b += color.b
        }
        let count = Double(cells.count)
        return (r / count, g / count, b / count)
    }

    private static func downsample(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        guard !Task.isCancelled else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard !Task.isCancelled else { return nil }
        // Bitmap contexts store row 0 at the image top, which already matches
        // the grid's top-down y.
        return pixels
    }

    private static func otsuThreshold(_ values: [Double]) -> Double {
        var histogram = [Int](repeating: 0, count: 64)
        for v in values {
            histogram[min(63, max(0, Int(v * 63)))] += 1
        }
        let total = values.count
        let totalSum = histogram.enumerated().reduce(0.0) { $0 + Double($1.offset) * Double($1.element) }
        var bestThreshold = 31
        var bestVariance = -1.0
        var backgroundCount = 0
        var backgroundSum = 0.0
        for bin in 0..<64 {
            backgroundCount += histogram[bin]
            guard backgroundCount > 0, backgroundCount < total else { continue }
            backgroundSum += Double(bin) * Double(histogram[bin])
            let foregroundCount = total - backgroundCount
            let meanB = backgroundSum / Double(backgroundCount)
            let meanF = (totalSum - backgroundSum) / Double(foregroundCount)
            let variance = Double(backgroundCount) * Double(foregroundCount) * (meanB - meanF) * (meanB - meanF)
            if variance > bestVariance {
                bestVariance = variance
                bestThreshold = bin
            }
        }
        return Double(bestThreshold) / 63.0
    }

    private static func removeIsolatedCells(_ cells: inout Set<GridPoint>) {
        while true {
            if Task.isCancelled { return }
            let isolated = cells.filter { cell in
                !cells.contains(GridPoint(x: cell.x + 1, y: cell.y)) &&
                !cells.contains(GridPoint(x: cell.x - 1, y: cell.y)) &&
                !cells.contains(GridPoint(x: cell.x, y: cell.y + 1)) &&
                !cells.contains(GridPoint(x: cell.x, y: cell.y - 1))
            }
            if isolated.isEmpty { return }
            cells.subtract(isolated)
        }
    }

    /// Perceptually weighted ("redmean") RGB distance over 0...1 components.
    /// Plain Euclidean RGB pairs dark red with green; this keeps hues apart.
    static func colorDistance(
        _ a: (r: Double, g: Double, b: Double),
        _ b: (r: Double, g: Double, b: Double)
    ) -> Double {
        let rMean = (a.r + b.r) / 2
        let dr = a.r - b.r
        let dg = a.g - b.g
        let db = a.b - b.b
        return ((2 + rMean) * dr * dr + 4 * dg * dg + (3 - rMean) * db * db).squareRoot()
    }

    /// Merges k-means clusters whose centers are too close for the player to
    /// read as different colors; the survivor keeps the weighted average.
    private static func mergeSimilarZones(
        _ assignment: inout [GridPoint: Int],
        centers: inout [(r: Double, g: Double, b: Double)]
    ) {
        while centers.count > 1 {
            if Task.isCancelled { return }
            var counts = [Int](repeating: 0, count: centers.count)
            for zone in assignment.values { counts[zone] += 1 }
            var pair: (Int, Int)?
            var bestDistance = 0.3
            for i in 0..<centers.count {
                for j in (i + 1)..<centers.count {
                    let d = colorDistance(centers[i], centers[j])
                    if d < bestDistance { bestDistance = d; pair = (i, j) }
                }
            }
            guard let (i, j) = pair else { return }
            let total = Double(max(1, counts[i] + counts[j]))
            centers[i] = (
                r: (centers[i].r * Double(counts[i]) + centers[j].r * Double(counts[j])) / total,
                g: (centers[i].g * Double(counts[i]) + centers[j].g * Double(counts[j])) / total,
                b: (centers[i].b * Double(counts[i]) + centers[j].b * Double(counts[j])) / total
            )
            centers.remove(at: j)
            for (cell, zone) in assignment {
                if zone == j { assignment[cell] = i } else if zone > j { assignment[cell] = zone - 1 }
            }
        }
    }

    private static func kMeans(
        cells: Set<GridPoint>,
        k: Int,
        pixels: [UInt8],
        gridW: Int
    ) -> ([GridPoint: Int], [(r: Double, g: Double, b: Double)])? {
        guard !Task.isCancelled else { return nil }
        let list = cells.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        let colors: [(Double, Double, Double)] = list.map { cell in
            let i = (cell.y * gridW + cell.x) * 4
            let alpha = max(1 / 255, Double(pixels[i + 3]) / 255)
            return (
                min(1, Double(pixels[i]) / 255 / alpha),
                min(1, Double(pixels[i + 1]) / 255 / alpha),
                min(1, Double(pixels[i + 2]) / 255 / alpha)
            )
        }
        // Deterministic farthest-color seeding separates equal-luminance hues
        // (for example a green leaf and dark orange shadow), which luminance-
        // only seeds used to merge into a muddy brown cluster.
        let average = (
            colors.reduce(0.0) { $0 + $1.0 } / Double(colors.count),
            colors.reduce(0.0) { $0 + $1.1 } / Double(colors.count),
            colors.reduce(0.0) { $0 + $1.2 } / Double(colors.count)
        )
        var centers: [(Double, Double, Double)] = [average]
        while centers.count < k {
            var farthest = colors[0]
            var farthestDistance = -Double.infinity
            for color in colors {
                let nearest = centers.map {
                    colorDistance(
                        (r: color.0, g: color.1, b: color.2),
                        (r: $0.0, g: $0.1, b: $0.2)
                    )
                }.min() ?? 0
                if nearest > farthestDistance {
                    farthestDistance = nearest
                    farthest = color
                }
            }
            centers.append(farthest)
        }

        var assignment = [Int](repeating: 0, count: list.count)
        for _ in 0..<12 {
            guard !Task.isCancelled else { return nil }
            for (index, color) in colors.enumerated() {
                var best = 0
                var bestDistance = Double.infinity
                for (centerIndex, center) in centers.enumerated() {
                    let d = colorDistance(
                        (r: color.0, g: color.1, b: color.2),
                        (r: center.0, g: center.1, b: center.2)
                    )
                    if d < bestDistance { bestDistance = d; best = centerIndex }
                }
                assignment[index] = best
            }
            var sums = [(Double, Double, Double)](repeating: (0, 0, 0), count: k)
            var counts = [Int](repeating: 0, count: k)
            for (index, color) in colors.enumerated() {
                let a = assignment[index]
                sums[a].0 += color.0; sums[a].1 += color.1; sums[a].2 += color.2
                counts[a] += 1
            }
            for center in 0..<k where counts[center] > 0 {
                centers[center] = (
                    sums[center].0 / Double(counts[center]),
                    sums[center].1 / Double(counts[center]),
                    sums[center].2 / Double(counts[center])
                )
            }
        }

        var result: [GridPoint: Int] = [:]
        for (index, cell) in list.enumerated() {
            guard !Task.isCancelled else { return nil }
            result[cell] = assignment[index]
        }
        return (result, centers.map { (r: $0.0, g: $0.1, b: $0.2) })
    }

    private static func lum(_ c: (Double, Double, Double)) -> Double {
        0.299 * c.0 + 0.587 * c.1 + 0.114 * c.2
    }

    /// Splits every zone into connected components; components smaller than
    /// `minSize` are merged into an orthogonally adjacent zone, or removed
    /// entirely when they touch nothing.
    private static func cleanupSmallComponents(_ assignment: inout [GridPoint: Int], minSize: Int) {
        // Iterate because a merge can form new small leftovers at the edges.
        for _ in 0..<4 {
            if Task.isCancelled { return }
            var visited = Set<GridPoint>()
            var changed = false
            for (start, zone) in assignment {
                guard !visited.contains(start) else { continue }
                // Flood-fill this zone-component.
                var component: [GridPoint] = []
                var stack = [start]
                visited.insert(start)
                while let cell = stack.popLast() {
                    if Task.isCancelled { return }
                    component.append(cell)
                    for neighbor in orthogonalNeighbors(of: cell)
                    where assignment[neighbor] == zone && !visited.contains(neighbor) {
                        visited.insert(neighbor)
                        stack.append(neighbor)
                    }
                }
                guard component.count < minSize else { continue }
                // Prefer merging into whichever zone borders the component.
                let neighborZone = component
                    .flatMap { orthogonalNeighbors(of: $0) }
                    .compactMap { assignment[$0] }
                    .first { $0 != zone }
                for cell in component {
                    if let neighborZone {
                        assignment[cell] = neighborZone
                    } else {
                        assignment.removeValue(forKey: cell)
                    }
                }
                changed = true
            }
            if !changed { return }
        }
    }

    private static func orthogonalNeighbors(of cell: GridPoint) -> [GridPoint] {
        [
            GridPoint(x: cell.x + 1, y: cell.y),
            GridPoint(x: cell.x - 1, y: cell.y),
            GridPoint(x: cell.x, y: cell.y + 1),
            GridPoint(x: cell.x, y: cell.y - 1),
        ]
    }

    /// Reassigns cells that have no same-zone orthogonal neighbor to the zone
    /// of one of their neighbors, so every zone can be snake-partitioned.
    private static func healZoneIslands(_ assignment: inout [GridPoint: Int]) {
        for _ in 0..<4 {
            if Task.isCancelled { return }
            var changed = false
            for (cell, zone) in assignment {
                let neighbors = [
                    GridPoint(x: cell.x + 1, y: cell.y),
                    GridPoint(x: cell.x - 1, y: cell.y),
                    GridPoint(x: cell.x, y: cell.y + 1),
                    GridPoint(x: cell.x, y: cell.y - 1),
                ].compactMap { assignment[$0] }
                guard !neighbors.isEmpty else { continue }
                if !neighbors.contains(zone) {
                    assignment[cell] = neighbors[0]
                    changed = true
                }
            }
            if !changed { return }
        }
    }
}
