import Foundation
import SwiftUI
import Observation

private nonisolated struct EditorValidationInput: Sendable {
    let pieces: [Piece]
    let obstacles: [Obstacle]
    let width: Int
    let height: Int
}

private actor EditorValidationWorker {
    func validate(_ input: EditorValidationInput) throws -> ValidationStatus {
        try Task.checkCancellation()
        if input.pieces.contains(where: { $0.kind == .double }) {
            return .skipped
        }

        let startedAt = Date()
        let order = solvePieces(
            pieces: input.pieces,
            obstacles: input.obstacles,
            width: input.width,
            height: input.height
        )
        try Task.checkCancellation()
        let seconds = -startedAt.timeIntervalSinceNow
        if let order {
            return .valid(moves: order.count, seconds: seconds)
        }
        return .unsolvable(seconds: seconds)
    }
}

@Observable
@MainActor
final class EditorViewModel {

    // MARK: - Identity
    let id: String

    // MARK: - Level data
    var index: Int = 1
    var name: String = ""
    var difficulty: String = "medium"
    var width: Int = 10
    var height: Int = 14
    var lives: Int = 5
    var pieces: [Piece] = []
    var obstacles: [Obstacle] = []
    var goal: LevelGoal = LevelGoal()
    var threeStarMaxMistakes: Int = 0
    var twoStarMaxMistakes: Int = 1

    // MARK: - Editor UI state
    var mode: EditorMode = .piece
    var cellSize: CGFloat = 42
    var currentPiece: Piece? = nil
    var selectedId: String? = nil
    var selectedKind: SelectionKind? = nil
    var validationStatus: ValidationStatus = .idle
    var showProperties: Bool = false
    var showExport: Bool = false

    // MARK: - Private
    private var nextPieceNum: Int = 1
    private var nextObstacleNum: Int = 1
    private var validationTask: Task<Void, Never>? = nil
    private let validationWorker = EditorValidationWorker()
    private var validationRevision: UInt = 0

    private enum DragIntent { case none, drawing, placing, erasing, selecting }
    private var dragIntent: DragIntent = .none

    // MARK: - Undo / Redo

    private struct Snapshot {
        let pieces: [Piece]
        let obstacles: [Obstacle]
    }
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private let maxUndoDepth = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    private func pushUndo() {
        undoStack.append(Snapshot(pieces: pieces, obstacles: obstacles))
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard let snap = undoStack.popLast() else { return }
        redoStack.append(Snapshot(pieces: pieces, obstacles: obstacles))
        pieces = snap.pieces
        obstacles = snap.obstacles
        deselect()
        scheduleValidation()
    }

    func redo() {
        guard let snap = redoStack.popLast() else { return }
        undoStack.append(Snapshot(pieces: pieces, obstacles: obstacles))
        pieces = snap.pieces
        obstacles = snap.obstacles
        deselect()
        scheduleValidation()
    }

    // MARK: - Init

    init(id: String = UUID().uuidString) {
        self.id = id
    }

    // MARK: - Piece helpers

    func piece(at cell: GridCell) -> Piece? {
        pieces.first { $0.cells.contains(cell) }
    }

    func obstacle(at cell: GridCell) -> Obstacle? {
        obstacles.first { $0.cell == cell }
    }

    private func nextPieceId() -> String {
        let id = "p\(nextPieceNum)"; nextPieceNum += 1; return id
    }
    private func nextObstacleId() -> String {
        let id = "o\(nextObstacleNum)"; nextObstacleNum += 1; return id
    }

    // MARK: - Drag events (called by GridCanvasView)

    func onDragStarted(at cell: GridCell) {
        switch mode {
        case .eraser:
            dragIntent = .erasing
            pushUndo()
            erase(at: cell)

        case .obstacle(let kind):
            dragIntent = .placing
            pushUndo()
            placeObstacle(kind: kind, at: cell)

        case .piece:
            if currentPiece == nil {
                if let p = piece(at: cell) {
                    selectPiece(p.id); dragIntent = .selecting; return
                }
                if let o = obstacle(at: cell) {
                    selectObstacle(o.id); dragIntent = .selecting; return
                }
                // Clicked empty cell — deselect if something was selected
                if selectedId != nil { deselect() }
                startPiece(at: cell)
                dragIntent = .drawing
            } else {
                extendPiece(to: cell)
                dragIntent = .drawing
            }
        }
    }

    func onDragMoved(to cell: GridCell) {
        switch dragIntent {
        case .drawing:  extendPiece(to: cell)
        case .placing:  if case .obstacle(let k) = mode { placeObstacle(kind: k, at: cell) }
        case .erasing:  erase(at: cell)
        default: break
        }
    }

    func onDragEnded() {
        dragIntent = .none
        scheduleValidation()
    }

    // MARK: - Actions

    func finishPiece() {
        guard let cp = currentPiece, cp.cells.count >= 2 else { currentPiece = nil; return }
        pushUndo()
        pieces.append(cp)
        currentPiece = nil
        scheduleValidation()
    }

    func cancelPiece() {
        currentPiece = nil
        scheduleValidation()
    }

    func deleteSelected() {
        if currentPiece != nil { cancelPiece(); return }
        guard let id = selectedId else { return }
        pushUndo()
        if selectedKind == .piece {
            pieces.removeAll { $0.id == id }
        } else {
            obstacles.removeAll { $0.id == id }
        }
        deselect()
        scheduleValidation()
    }

    func updatePiece(id: String, transform: (inout Piece) -> Void) {
        guard let i = pieces.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        transform(&pieces[i])
        scheduleValidation()
    }

    func updateObstacle(id: String, transform: (inout Obstacle) -> Void) {
        guard let i = obstacles.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        transform(&obstacles[i])
        scheduleValidation()
    }

    // MARK: - Private drawing

    private func startPiece(at cell: GridCell) {
        let pid = nextPieceId()
        currentPiece = Piece(id: pid, direction: .right, cells: [cell])
    }

    private func extendPiece(to cell: GridCell) {
        guard var cp = currentPiece else { return }
        guard !cp.cells.contains(cell) else { return }
        guard let last = cp.cells.last else { return }
        let dx = cell.x - last.x, dy = cell.y - last.y
        guard abs(dx) + abs(dy) == 1 else { return }
        guard piece(at: cell) == nil, obstacle(at: cell) == nil else { return }
        cp.cells.append(cell)
        if let dir = Direction.from(dx: dx, dy: dy) { cp.direction = dir }
        currentPiece = cp
    }

    private func placeObstacle(kind: ObstacleKind, at cell: GridCell) {
        guard piece(at: cell) == nil, obstacle(at: cell) == nil else { return }
        var ob = Obstacle(id: nextObstacleId(), kind: kind, cell: cell)
        if kind == .gate { ob.parameter = "right" }
        obstacles.append(ob)
    }

    private func erase(at cell: GridCell) {
        if let p = piece(at: cell) {
            pieces.removeAll { $0.id == p.id }
            if selectedKind == .piece && selectedId == p.id { deselect() }
        } else if let o = obstacle(at: cell) {
            obstacles.removeAll { $0.id == o.id }
            if selectedKind == .obstacle && selectedId == o.id { deselect() }
        }
    }

    private func selectPiece(_ pid: String) {
        commitCurrentPiece()
        selectedId = pid; selectedKind = .piece; showProperties = true
    }

    private func selectObstacle(_ oid: String) {
        commitCurrentPiece()
        selectedId = oid; selectedKind = .obstacle; showProperties = true
    }

    func deselect() {
        selectedId = nil; selectedKind = nil
    }

    private func commitCurrentPiece() {
        if let cp = currentPiece, cp.cells.count >= 2 { pieces.append(cp) }
        currentPiece = nil
    }

    // MARK: - Validation

    func scheduleValidation() {
        validationTask?.cancel()
        validationRevision &+= 1
        let revision = validationRevision
        validationStatus = pieces.isEmpty ? .idle : .checking

        validationTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard let self,
                  !Task.isCancelled,
                  self.validationRevision == revision
            else { return }
            await self.runValidation(revision: revision)
        }
    }

    func cancelValidation() {
        validationRevision &+= 1
        validationTask?.cancel()
        validationTask = nil
        if validationStatus == .checking {
            validationStatus = .idle
        }
    }

    private func runValidation(revision: UInt) async {
        guard validationRevision == revision, !Task.isCancelled else { return }
        let ps = pieces, obs = obstacles, w = width, h = height
        if ps.isEmpty {
            validationStatus = .idle
            validationTask = nil
            return
        }
        if let err = validateCheap(pieces: ps, obstacles: obs, width: w, height: h) {
            guard validationRevision == revision, !Task.isCancelled else { return }
            validationStatus = .invalid(reason: err)
            validationTask = nil
            return
        }
        validationStatus = .checking
        let input = EditorValidationInput(pieces: ps, obstacles: obs, width: w, height: h)

        do {
            let result = try await validationWorker.validate(input)
            try Task.checkCancellation()
            guard validationRevision == revision else { return }
            validationStatus = result
            validationTask = nil
        } catch is CancellationError {
            // A newer document revision or view disappearance owns the status.
        } catch {
            guard validationRevision == revision else { return }
            validationStatus = .invalid(reason: error.localizedDescription)
            validationTask = nil
        }
    }

    // MARK: - JSON export (game format)

    func exportGameJSON() throws -> String {
        var dict: [String: Any] = [
            "id":                   String(format: "level_%03d", index),
            "index":                index,
            "difficulty":           difficulty,
            "width":                width,
            "height":               height,
            "lives":                lives,
            "threeStarMaxMistakes": threeStarMaxMistakes,
            "twoStarMaxMistakes":   twoStarMaxMistakes,
            "pieces":               pieces.map { pieceDict($0) },
        ]
        if !name.isEmpty { dict["name"] = name }
        if !obstacles.isEmpty { dict["obstacles"] = obstacles.map { obstacleDict($0) } }
        if goal.kind != .clearAll {
            var gd: [String: Any] = ["kind": goal.kind.rawValue]
            if goal.kind.needsValue && !goal.valueString.isEmpty {
                gd["value"] = Int(goal.valueString) ?? goal.valueString as Any
            }
            dict["goal"] = gd
        }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Storage serialization

    func toStorageDict() -> [String: Any] {
        var d: [String: Any] = [
            "localId":              id,
            "index":                index,
            "name":                 name,
            "difficulty":           difficulty,
            "width":                width,
            "height":               height,
            "lives":                lives,
            "threeStarMaxMistakes": threeStarMaxMistakes,
            "twoStarMaxMistakes":   twoStarMaxMistakes,
            "nextPieceNum":         nextPieceNum,
            "nextObstacleNum":      nextObstacleNum,
            "pieces":               pieces.map { pieceDict($0) },
            "goal":                 ["kind": goal.kind.rawValue, "value": goal.valueString],
        ]
        if !obstacles.isEmpty { d["obstacles"] = obstacles.map { obstacleDict($0) } }
        return d
    }

    static func from(dict: [String: Any]) -> EditorViewModel? {
        guard let w = dict["width"] as? Int, let h = dict["height"] as? Int else { return nil }
        let vm = EditorViewModel(id: dict["localId"] as? String ?? UUID().uuidString)
        vm.width = w; vm.height = h
        vm.index      = dict["index"]      as? Int    ?? 1
        vm.name       = dict["name"]       as? String ?? ""
        vm.difficulty = dict["difficulty"] as? String ?? "medium"
        vm.lives      = dict["lives"]      as? Int    ?? 5
        vm.threeStarMaxMistakes = dict["threeStarMaxMistakes"] as? Int ?? 0
        vm.twoStarMaxMistakes   = dict["twoStarMaxMistakes"]   as? Int ?? 1
        vm.nextPieceNum    = dict["nextPieceNum"]    as? Int ?? 1
        vm.nextObstacleNum = dict["nextObstacleNum"] as? Int ?? 1

        if let arr = dict["pieces"] as? [[String: Any]] {
            vm.pieces = arr.compactMap { pd -> Piece? in
                guard let id  = pd["id"] as? String,
                      let dir = pd["direction"].flatMap({ Direction(rawValue: $0 as? String ?? "") }),
                      let ca  = pd["cells"] as? [[String: Any]] else { return nil }
                let cells = ca.compactMap { c -> GridCell? in
                    guard let x = c["x"] as? Int, let y = c["y"] as? Int else { return nil }
                    return GridCell(x: x, y: y)
                }
                var p = Piece(id: id, direction: dir, cells: cells)
                if let k = pd["kind"] as? String { p.kind = PieceKind(rawValue: k) ?? .standard }
                p.colorGroup            = pd["colorGroup"]            as? Int
                p.frozenUnlockNeighbors = pd["frozenUnlockNeighbors"] as? Int
                p.chainedPieceId        = pd["chainedPieceId"]        as? String
                if let sd = pd["secondaryDirection"] as? String { p.secondaryDirection = Direction(rawValue: sd) }
                return p
            }
        }

        if let arr = dict["obstacles"] as? [[String: Any]] {
            vm.obstacles = arr.compactMap { od -> Obstacle? in
                guard let id   = od["id"]   as? String,
                      let kind = (od["kind"] as? String).flatMap({ ObstacleKind(rawValue: $0) }),
                      let cd   = od["cell"] as? [String: Any],
                      let cx   = cd["x"] as? Int, let cy = cd["y"] as? Int else { return nil }
                var o = Obstacle(id: id, kind: kind, cell: GridCell(x: cx, y: cy))
                o.parameter  = od["parameter"]  as? String
                o.colorGroup = od["colorGroup"] as? Int
                return o
            }
        }

        if let gd = dict["goal"] as? [String: Any],
           let ks = gd["kind"] as? String,
           let kind = GoalKind(rawValue: ks) {
            var g = LevelGoal(kind: kind)
            if let v = gd["value"] {
                g.valueString = (v as? Int).map { "\($0)" } ?? (v as? String ?? "")
            }
            vm.goal = g
        }
        return vm
    }

    // MARK: - Private dict helpers

    private func pieceDict(_ p: Piece) -> [String: Any] {
        var d: [String: Any] = [
            "id":        p.id,
            "direction": p.direction.rawValue,
            "cells":     p.cells.map { ["x": $0.x, "y": $0.y] },
        ]
        if p.kind != .standard { d["kind"] = p.kind.rawValue }
        if let v = p.colorGroup            { d["colorGroup"]            = v }
        if let v = p.secondaryDirection    { d["secondaryDirection"]    = v.rawValue }
        if let v = p.frozenUnlockNeighbors { d["frozenUnlockNeighbors"] = v }
        if let v = p.chainedPieceId        { d["chainedPieceId"]        = v }
        return d
    }

    private func obstacleDict(_ o: Obstacle) -> [String: Any] {
        var d: [String: Any] = [
            "id":   o.id,
            "kind": o.kind.rawValue,
            "cell": ["x": o.cell.x, "y": o.cell.y],
        ]
        if let v = o.parameter  { d["parameter"]  = v }
        if let v = o.colorGroup { d["colorGroup"] = v }
        return d
    }
}

// MARK: - Computed helpers for views

extension EditorViewModel {
    var selectedPiece: Piece? {
        guard selectedKind == .piece, let id = selectedId else { return nil }
        return pieces.first { $0.id == id }
    }
    var selectedObstacle: Obstacle? {
        guard selectedKind == .obstacle, let id = selectedId else { return nil }
        return obstacles.first { $0.id == id }
    }

    var validationColor: Color {
        switch validationStatus {
        case .valid:       .green
        case .invalid, .unsolvable: .red
        case .checking:    .yellow
        case .skipped:     .gray
        case .idle:        .gray
        }
    }

    var validationText: String {
        switch validationStatus {
        case .idle:                      "Ожидание"
        case .checking:                  "Проверяю…"
        case .valid(let m, let s):       String(format: "Решаемо — %d ходов (%.2fс)", m, s)
        case .invalid(let r):            r
        case .unsolvable(let s):         String(format: "Нерешаемо (%.2fс)", s)
        case .skipped:                   "Double-фигуры — пропущено"
        }
    }
}
