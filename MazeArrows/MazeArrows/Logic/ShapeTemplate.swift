//
//  ShapeTemplate.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Library of arrow shapes for the level generator. Each template is a
//  connected polyline of grid cells, with the head at the LAST cell pointing
//  in `direction`. The generator clones a template, rotates/mirrors it, and
//  places it on the board.
//

import Foundation

nonisolated struct ShapeTemplate: Sendable {
    /// Cells relative to the template origin (0,0). Each pair differs by one
    /// unit horizontally or vertically.
    let cells: [GridPoint]
    /// Direction the tip points to (last cell).
    let direction: Direction
    /// Number of turns in the path — for difficulty filtering.
    var turns: Int {
        var count = 0
        guard cells.count >= 3 else { return 0 }
        for i in 1..<(cells.count - 1) {
            let a = cells[i - 1], b = cells[i], c = cells[i + 1]
            let ax = b.x - a.x, ay = b.y - a.y
            let bx = c.x - b.x, by = c.y - b.y
            if ax != bx || ay != by { count += 1 }
        }
        return count
    }
}

nonisolated enum ShapeTemplates {

    /// Straight line of `length` cells.
    static func straight(length: Int, direction: Direction = .right) -> ShapeTemplate {
        var cells: [GridPoint] = []
        for i in 0..<length {
            cells.append(GridPoint(x: i * direction.dx, y: i * direction.dy))
        }
        return ShapeTemplate(cells: cells, direction: direction)
    }

    /// Hand-crafted library — a mix of L, U, S, comb, stair, zigzag forms.
    static var library: [ShapeTemplate] { _library }
    private static let _library: [ShapeTemplate] = makeLibrary()

    private static func makeLibrary() -> [ShapeTemplate] {
        func p(_ x: Int, _ y: Int) -> GridPoint { GridPoint(x: x, y: y) }
        var result: [ShapeTemplate] = []
        result.append(ShapeTemplate(cells: [p(0,0), p(1,0)], direction: .right))
        result.append(ShapeTemplate(cells: [p(0,0), p(1,0), p(2,0)], direction: .right))
        result.append(ShapeTemplate(cells: [p(0,0), p(1,0), p(2,0), p(3,0)], direction: .right))
        result.append(ShapeTemplate(
            cells: [p(0,0), p(0,1), p(1,1), p(2,1)],
            direction: .right
        ))
        result.append(ShapeTemplate(
            cells: [p(0,0), p(1,0), p(2,0), p(2,1)],
            direction: .down
        ))
        result.append(ShapeTemplate(
            cells: [p(0,0), p(0,1), p(0,2), p(1,2), p(2,2), p(2,1), p(2,0)],
            direction: .up
        ))
        result.append(ShapeTemplate(
            cells: [p(0,0), p(1,0), p(1,1), p(2,1), p(2,2), p(3,2)],
            direction: .right
        ))
        result.append(ShapeTemplate(
            cells: [p(0,0), p(1,0), p(2,0), p(2,1), p(2,2)],
            direction: .down
        ))
        result.append(ShapeTemplate(
            cells: [p(0,2), p(1,2), p(1,1), p(2,1), p(2,0), p(3,0)],
            direction: .right
        ))
        result.append(ShapeTemplate(
            cells: [p(0,0), p(1,0), p(1,1), p(0,1), p(0,2), p(1,2)],
            direction: .right
        ))
        return result
    }

    // Rotations of grid coords. Rotation is applied around the origin and then
    // the path is re-normalized so that the minimum coordinate is at (0,0).
    nonisolated private static func rotate(_ p: GridPoint, _ steps: Int) -> GridPoint {
        var x = p.x, y = p.y
        for _ in 0..<((steps % 4 + 4) % 4) {
            let nx = -y
            let ny = x
            x = nx; y = ny
        }
        return GridPoint(x: x, y: y)
    }

    nonisolated private static func rotate(_ direction: Direction, _ steps: Int) -> Direction {
        let order: [Direction] = [.right, .down, .left, .up]
        let idx = order.firstIndex(of: direction) ?? 0
        return order[(idx + ((steps % 4 + 4) % 4)) % 4]
    }

    nonisolated private static func mirror(_ p: GridPoint) -> GridPoint {
        GridPoint(x: -p.x, y: p.y)
    }

    nonisolated private static func mirror(_ direction: Direction) -> Direction {
        switch direction {
        case .left: return .right
        case .right: return .left
        case .up, .down: return direction
        }
    }

    nonisolated private static func normalize(cells: [GridPoint]) -> [GridPoint] {
        let minX = cells.map(\.x).min() ?? 0
        let minY = cells.map(\.y).min() ?? 0
        return cells.map { GridPoint(x: $0.x - minX, y: $0.y - minY) }
    }

    nonisolated static func variants(of template: ShapeTemplate) -> [ShapeTemplate] {
        var out: [ShapeTemplate] = []
        for steps in 0..<4 {
            for mirrored in [false, true] {
                var cells = template.cells.map { rotate($0, steps) }
                var dir = rotate(template.direction, steps)
                if mirrored {
                    cells = cells.map(mirror)
                    dir = mirror(dir)
                }
                out.append(ShapeTemplate(cells: normalize(cells: cells), direction: dir))
            }
        }
        // Deduplicate by serialized shape+direction.
        var seen = Set<String>()
        var deduped: [ShapeTemplate] = []
        for t in out {
            let key = t.cells.map { "\($0.x),\($0.y)" }.joined(separator: "|") + "/" + t.direction.rawValue
            if seen.insert(key).inserted {
                deduped.append(t)
            }
        }
        return deduped
    }

    /// Translate a template so that its first cell maps to `origin`.
    static func placed(_ template: ShapeTemplate, at origin: GridPoint) -> [GridPoint] {
        template.cells.map { GridPoint(x: $0.x + origin.x, y: $0.y + origin.y) }
    }
}
