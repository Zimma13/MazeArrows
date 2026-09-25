import Foundation

// MARK: - Validation

nonisolated func validatePiece(_ p: Piece, width: Int, height: Int) -> String? {
    guard p.cells.count >= 2 else { return "Фигура \(p.id): менее 2 клеток" }
    let set = Set(p.cells)
    guard set.count == p.cells.count else { return "Фигура \(p.id): дублирующиеся клетки" }
    for c in p.cells {
        guard (0..<width).contains(c.x) && (0..<height).contains(c.y) else {
            return "Фигура \(p.id): клетка (\(c.x),\(c.y)) вне \(width)×\(height)"
        }
    }
    for i in 1..<p.cells.count {
        let a = p.cells[i - 1], b = p.cells[i]
        guard abs(a.x - b.x) + abs(a.y - b.y) == 1 else {
            return "Фигура \(p.id): несмежные клетки"
        }
    }
    let last = p.cells[p.cells.count - 1]
    let prev = p.cells[p.cells.count - 2]
    let d = p.direction.delta
    guard last.x - prev.x == d.dx && last.y - prev.y == d.dy else {
        return "Фигура \(p.id): направление не совпадает с последним сегментом"
    }
    return nil
}

nonisolated func validateCheap(pieces: [Piece], obstacles: [Obstacle], width: Int, height: Int) -> String? {
    guard !pieces.isEmpty else { return "Нет фигур" }
    var occ: [GridCell: String] = [:]
    for p in pieces {
        if let err = validatePiece(p, width: width, height: height) { return err }
        for c in p.cells {
            if let other = occ[c] { return "Перекрытие: \(other) и \(p.id) в (\(c.x),\(c.y))" }
            occ[c] = p.id
        }
    }
    for o in obstacles {
        let c = o.cell
        guard (0..<width).contains(c.x) && (0..<height).contains(c.y) else {
            return "Препятствие \(o.id) за пределами сетки"
        }
        if let pid = occ[c] { return "Препятствие \(o.id) перекрывает фигуру \(pid)" }
    }
    return nil
}

// MARK: - Solver

nonisolated func canFlyOut(
    _ p: Piece,
    remaining: [Piece],
    obstacles: [Obstacle],
    width: Int, height: Int,
    removedCount: Int
) -> Bool {
    guard !Task.isCancelled else { return false }
    if p.kind == .frozen {
        if removedCount < (p.frozenUnlockNeighbors ?? 1) { return false }
    }
    if p.kind == .lockedLock, let group = p.colorGroup {
        let hasKey = remaining.contains { $0.id != p.id && $0.kind == .lockedKey && $0.colorGroup == group }
        if hasKey { return false }
    }

    var occ: [GridCell: Void] = [:]
    for q in remaining where q.id != p.id {
        guard !Task.isCancelled else { return false }
        for c in q.cells { occ[c] = () }
    }
    let obsMap = Dictionary(uniqueKeysWithValues: obstacles.map { ($0.cell, $0) })

    let d = p.direction.delta
    var cx = p.cells.last!.x
    var cy = p.cells.last!.y

    while true {
        guard !Task.isCancelled else { return false }
        let nx = cx + d.dx, ny = cy + d.dy
        guard (0..<width).contains(nx) && (0..<height).contains(ny) else { return true }
        let nc = GridCell(x: nx, y: ny)
        if occ[nc] != nil { return false }
        if let ob = obsMap[nc] {
            switch ob.kind {
            case .wall:
                return false
            case .gate:
                if let gd = ob.parameter.flatMap({ Direction(rawValue: $0) }), gd != p.direction { return false }
                if let og = ob.colorGroup, og != p.colorGroup { return false }
            case .destructible:
                if p.kind != .bomb { return false }
            case .portal, .ice, .spring:
                break
            }
        }
        cx = nx; cy = ny
    }
}

nonisolated func solvePieces(pieces: [Piece], obstacles: [Obstacle], width: Int, height: Int) -> [String]? {
    guard !Task.isCancelled else { return nil }
    var remaining = pieces
    var obs = obstacles
    let initial = remaining.count
    var order: [String] = []
    var safety = 0

    while !remaining.isEmpty {
        guard !Task.isCancelled else { return nil }
        safety += 1
        if safety > 1000 { return nil }
        var moved = false
        for p in remaining {
            guard !Task.isCancelled else { return nil }
            let removed = initial - remaining.count
            guard canFlyOut(p, remaining: remaining, obstacles: obs, width: width, height: height, removedCount: removed)
            else { continue }

            order.append(p.id)
            remaining.removeAll { $0.id == p.id }

            if p.kind == .bomb {
                let body = Set(p.cells)
                obs.removeAll { o in
                    o.kind == .destructible &&
                    body.contains { abs($0.x - o.cell.x) + abs($0.y - o.cell.y) == 1 }
                }
            }
            if p.kind == .chain, let cid = p.chainedPieceId,
               let chained = remaining.first(where: { $0.id == cid }) {
                let removed2 = initial - remaining.count
                if canFlyOut(chained, remaining: remaining, obstacles: obs, width: width, height: height, removedCount: removed2) {
                    order.append(chained.id)
                    remaining.removeAll { $0.id == cid }
                }
            }
            moved = true
            break
        }
        if !moved { return nil }
    }
    return order
}
