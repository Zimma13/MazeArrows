//
//  LevelSolver.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Greedy + bounded DFS solver. Because removing a piece can only unblock
//  others (never create new constraints), greedy succeeds for almost any
//  generated level. We fall back to DFS for pathological cases.
//

import Foundation

nonisolated enum LevelSolver {

    /// Returns a sequence of piece IDs in the order they should be cleared,
    /// or nil if the level is unsolvable.
    static func solve(board: Board, maxDFS: Int = 20_000) -> [String]? {
        guard !Task.isCancelled else { return nil }
        if let greedy = greedy(board: board) { return greedy }
        guard !Task.isCancelled else { return nil }
        var visited: Set<[String]> = []
        var steps = 0
        return dfs(board: board, path: [], visited: &visited, steps: &steps, limit: maxDFS)
    }

    static func greedy(board: Board) -> [String]? {
        guard !Task.isCancelled else { return nil }
        // Plain boards (photo levels, most generated levels) take the
        // incremental fast path; special piece kinds and obstacles change
        // availability in ways it doesn't model.
        if board.obstacles.isEmpty, board.pieces.allSatisfy({ $0.kind == .standard }) {
            return fastGreedyStandard(board: board)
        }
        var board = board
        var solution: [String] = []

        while !board.pieces.isEmpty {
            guard !Task.isCancelled else { return nil }
            let movable = MoveValidator.availableMoves(board: board)
            if movable.isEmpty { return nil }
            // Take the first movable — order is irrelevant for the
            // monotone clearance property.
            let piece = movable[0]
            solution.append(piece.id)
            board.removePiece(id: piece.id)
        }
        return solution
    }

    /// Greedy for standard-pieces-only boards with incremental unblocking:
    /// a removal can only free pieces, never block them, so instead of
    /// rescanning the whole board after every move we remember each blocked
    /// piece's current blocker and recheck only the pieces that blocker was
    /// holding. Picks the lowest-index movable piece — the same piece
    /// `availableMoves(board:)[0]` would return, so solutions are identical
    /// to the generic loop's.
    private static func fastGreedyStandard(board: Board) -> [String]? {
        guard !Task.isCancelled else { return nil }
        let pieces = board.pieces
        let count = pieces.count
        if count == 0 { return [] }
        let width = board.width
        let height = board.height

        var occupied = [Int32](repeating: -1, count: width * height)
        for (index, piece) in pieces.enumerated() {
            guard !Task.isCancelled else { return nil }
            for (cellIndex, cell) in piece.cells.enumerated() where board.isInside(cell) {
                if cellIndex.isMultiple(of: 64), Task.isCancelled { return nil }
                occupied[cell.y * width + cell.x] = Int32(index)
            }
        }

        // First piece on the exit lane (own body is passable), -1 if clear.
        func firstBlocker(of index: Int) -> Int32 {
            let piece = pieces[index]
            let dir = piece.direction
            var x = piece.headCell.x + dir.dx
            var y = piece.headCell.y + dir.dy
            while x >= 0, x < width, y >= 0, y < height {
                let blocker = occupied[y * width + x]
                if blocker >= 0, blocker != Int32(index) { return blocker }
                x += dir.dx
                y += dir.dy
            }
            return -1
        }

        var blockerOf = [Int32](repeating: -1, count: count)
        var blocking = [[Int32]](repeating: [], count: count)
        var movable = [Bool](repeating: false, count: count)
        for index in 0..<count {
            guard !Task.isCancelled else { return nil }
            let blocker = firstBlocker(of: index)
            blockerOf[index] = blocker
            if blocker >= 0 {
                blocking[Int(blocker)].append(Int32(index))
            } else {
                movable[index] = true
            }
        }

        var removed = [Bool](repeating: false, count: count)
        var solution: [String] = []
        solution.reserveCapacity(count)

        for _ in 0..<count {
            guard !Task.isCancelled else { return nil }
            var pick = -1
            for index in 0..<count where movable[index] {
                pick = index
                break
            }
            guard pick >= 0 else { return nil }
            removed[pick] = true
            movable[pick] = false
            solution.append(pieces[pick].id)
            for (cellIndex, cell) in pieces[pick].cells.enumerated() where board.isInside(cell) {
                if cellIndex.isMultiple(of: 64), Task.isCancelled { return nil }
                occupied[cell.y * width + cell.x] = -1
            }
            // Only pieces this one was holding can change state; entries
            // whose blocker moved on since are skipped by the guard.
            for blocked32 in blocking[pick] {
                guard !Task.isCancelled else { return nil }
                let blocked = Int(blocked32)
                guard !removed[blocked], blockerOf[blocked] == Int32(pick) else { continue }
                let next = firstBlocker(of: blocked)
                blockerOf[blocked] = next
                if next >= 0 {
                    blocking[Int(next)].append(blocked32)
                } else {
                    movable[blocked] = true
                }
            }
            blocking[pick].removeAll()
        }
        return solution
    }

    private static func dfs(
        board: Board,
        path: [String],
        visited: inout Set<[String]>,
        steps: inout Int,
        limit: Int
    ) -> [String]? {
        guard !Task.isCancelled else { return nil }
        if board.pieces.isEmpty { return path }
        if steps >= limit { return nil }
        steps += 1
        let movable = MoveValidator.availableMoves(board: board)
        if movable.isEmpty { return nil }
        for piece in movable {
            guard !Task.isCancelled else { return nil }
            let next = path + [piece.id]
            let key = next.sorted()
            if visited.contains(key) { continue }
            visited.insert(key)
            var nextBoard = board
            nextBoard.removePiece(id: piece.id)
            if let solved = dfs(board: nextBoard, path: next, visited: &visited, steps: &steps, limit: limit) {
                return solved
            }
        }
        return nil
    }

    /// Returns the first piece in the solution path that is currently available,
    /// or nil if the puzzle cannot be solved from the current state.
    static func nextHintPiece(board: Board) -> ArrowPiece? {
        guard !Task.isCancelled else { return nil }
        guard let order = solve(board: board) else {
            return MoveValidator.availableMoves(board: board).first
        }
        let dict = Dictionary(uniqueKeysWithValues: board.pieces.map { ($0.id, $0) })
        for id in order {
            if let p = dict[id], MoveValidator.canFlyOut(piece: p, board: board) {
                return p
            }
        }
        return nil
    }
}
