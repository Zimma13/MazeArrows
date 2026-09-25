//
//  ArrowPieceNode.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Single-shape rendering of a maze-arrow piece: the body polyline AND the
//  chevron arrow head share one CGPath / SKShapeNode. This guarantees that
//  during the snake fly-out animation they cannot drift out of sync —
//  rendering the body and head as separate nodes used to produce visible
//  "missing chunks" / blinking artifacts at the head/body junction.
//

import SpriteKit
import UIKit

final class ArrowPieceNode: SKNode {
    let pieceId: String
    private(set) var piece: ArrowPiece
    private let geometry: BoardGeometry

    private let strokeWidth: CGFloat
    private let lineColor: UIColor
    private let blockedColor: UIColor
    private let hintColor: UIColor
    private let outlineColor: UIColor
    private let useGlow: Bool
    private let showsOutline: Bool
    private var reduceMotion: Bool
    private let chevronHalf: CGFloat
    private let usesDenseBoardMetrics: Bool
    private let outlineStrokeWidth: CGFloat

    private let contrastShape: SKShapeNode
    private let mainShape: SKShapeNode
    private var baseRenderPath: CGPath?
    private var renderScale: CGFloat = 1
    /// Per-piece tint based on `kind` / `colorGroup`. Used for fragile + locked
    /// pairs so the player can tell groups apart at a glance.
    private let renderColor: UIColor
    private var kindBadges: [SKNode] = []
    private var stateBadge: SKLabelNode?
    private var blockedCompletion: (() -> Void)?
    private var flyOutCompletion: (() -> Void)?

    private(set) var isLeaving = false

    init(
        piece: ArrowPiece,
        geometry: BoardGeometry,
        lineColor: UIColor,
        piecePalette: [PieceGroupPaletteColor] = [],
        highlightColor: UIColor = .systemRed,
        hintColor: UIColor = .systemGreen,
        outlineColor: UIColor = .black,
        useGlow: Bool = false,
        showsOutline: Bool = false,
        reduceMotion: Bool = false
    ) {
        self.piece = piece
        self.pieceId = piece.id
        self.geometry = geometry
        self.lineColor = lineColor
        self.blockedColor = highlightColor
        self.hintColor = hintColor
        self.outlineColor = outlineColor
        self.useGlow = useGlow
        self.showsOutline = showsOutline
        self.reduceMotion = reduceMotion
        // Photo mazes can have 100+ cells per axis. Absolute minimums that
        // look good on campaign boards make a dense arrow stroke wider than
        // its own chevron, so zoom only enlarges a visually merged shape.
        // Keep dense-board artwork proportional; the camera can then reveal
        // real detail instead of magnifying the minimum-size stroke.
        let usesDenseBoardMetrics = !piecePalette.isEmpty && geometry.cellSize < 8
        self.usesDenseBoardMetrics = usesDenseBoardMetrics
        if usesDenseBoardMetrics {
            let factor: CGFloat = piece.kind == .heavy ? 1.35 : 1
            self.strokeWidth = min(
                geometry.cellSize * 0.30,
                geometry.cellSize * 0.22 * factor
            )
            self.chevronHalf = geometry.cellSize
                * (piece.kind == .heavy ? 0.36 : 0.34)
        } else {
            // Keep pieces compact so adjacent arrows can sit close without
            // their heads visually dominating the cell.
            let baseWidth = min(8, max(2.0, geometry.cellSize * 0.22))
            let factor: CGFloat = piece.kind == .heavy ? 1.35 : 1
            self.strokeWidth = min(geometry.cellSize * 0.46, baseWidth * factor)
            self.chevronHalf = min(
                geometry.cellSize * 0.30,
                max(3.0, geometry.cellSize * 0.23)
                    * (piece.kind == .heavy ? 1.10 : 1.0)
            )
        }
        let outlineExtra = usesDenseBoardMetrics
            ? geometry.cellSize * 0.04
            : max(1.5, geometry.cellSize * 0.08)
        self.outlineStrokeWidth = self.strokeWidth + outlineExtra
        self.contrastShape = SKShapeNode()
        self.mainShape = SKShapeNode()
        self.renderColor = Self.tint(
            for: piece,
            base: lineColor,
            palette: piecePalette.isEmpty ? PieceGroupPalette.colors : piecePalette
        )

        super.init()
        self.name = piece.id
        setup()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is unavailable") }

    /// Zone palette for picture levels — a standard piece with colorGroup > 0
    /// is tinted by its image zone. Group 0 / nil keeps the theme ink color.
    /// Only append entries: shared/baked levels store the group index.
    private static func tint(
        for piece: ArrowPiece,
        base: UIColor,
        palette: [PieceGroupPaletteColor]
    ) -> UIColor {
        switch piece.kind {
        case .standard, .heavy:
            if let group = piece.colorGroup, group > 0, !palette.isEmpty {
                let color = palette[(group - 1) % palette.count]
                return UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1.0)
            }
            return base
        case .fragile:
            return UIColor(red: 0.95, green: 0.55, blue: 0.55, alpha: 1.0)
        case .frozen:
            return UIColor(red: 0.4, green: 0.75, blue: 0.95, alpha: 1.0)
        case .double:
            return UIColor(red: 0.85, green: 0.55, blue: 0.95, alpha: 1.0)
        case .lockedLock:
            return UIColor(red: 0.55, green: 0.45, blue: 0.30, alpha: 1.0)
        case .lockedKey:
            return UIColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1.0)
        case .bomb:
            return UIColor(red: 0.30, green: 0.20, blue: 0.20, alpha: 1.0)
        case .chain:
            return UIColor(red: 0.55, green: 0.75, blue: 0.55, alpha: 1.0)
        }
    }

    private func setup() {
        let body = Self.simplifiedRenderCells(piece.cells).map { geometry.point(for: $0) }
        let path = Self.buildPath(
            body: body,
            headAngle: piece.direction.spriteAngle,
            chevronHalf: chevronHalf
        )
        setRenderPath(path)
        contrastShape.strokeColor = outlineColor
        contrastShape.lineWidth = outlineStrokeWidth
        contrastShape.lineCap = .round
        contrastShape.lineJoin = .round
        contrastShape.fillColor = .clear
        contrastShape.isAntialiased = true
        contrastShape.zPosition = 0
        if showsOutline {
            addChild(contrastShape)
        }

        mainShape.strokeColor = renderColor
        mainShape.lineWidth = strokeWidth
        mainShape.lineCap = .round
        mainShape.lineJoin = .round
        mainShape.fillColor = .clear
        mainShape.isAntialiased = true
        mainShape.zPosition = 1
        if useGlow, !usesDenseBoardMetrics {
            // A glow is useful on regular Neon boards, but on a dense photo
            // board camera magnification enlarges the halo until it swallows
            // the chevron. Keep Photo Maze as a crisp vector stroke instead.
            mainShape.glowWidth = strokeWidth * 0.45
        }
        addChild(mainShape)

        addKindBadges()

    }

    /// SKShapeNode antialiasing is evaluated before the camera magnifies the
    /// scene, so a dense path can still look soft at a 10×+ zoom. Rebuild the
    /// compact path at the matching resolution, then cancel that local scale;
    /// the arrow keeps identical scene geometry while gaining enough samples
    /// for a crisp final image.
    func setCameraRenderScale(_ requestedScale: CGFloat) {
        guard usesDenseBoardMetrics else { return }
        let newScale = min(16, max(1, requestedScale))
        guard abs(newScale - renderScale) > 0.01 else { return }

        renderScale = newScale
        let inverseScale = 1 / newScale
        mainShape.setScale(inverseScale)
        contrastShape.setScale(inverseScale)
        mainShape.lineWidth = strokeWidth * newScale
        contrastShape.lineWidth = outlineStrokeWidth * newScale
        if let baseRenderPath {
            applyRenderPath(baseRenderPath)
        }
    }

    private func setRenderPath(_ path: CGPath) {
        baseRenderPath = path
        applyRenderPath(path)
    }

    private func applyRenderPath(_ path: CGPath) {
        if !usesDenseBoardMetrics {
            mainShape.path = path
            contrastShape.path = path
            return
        }

        var transform = CGAffineTransform(
            scaleX: renderScale,
            y: renderScale
        )
        let scaledPath = path.copy(using: &transform) ?? path
        mainShape.path = scaledPath
        contrastShape.path = scaledPath
    }

    /// Small icon decorations that identify the piece kind to the player.
    private func addKindBadges() {
        kindBadges.forEach { $0.removeFromParent() }
        kindBadges.removeAll()
        let tail = geometry.point(for: piece.tailCell)
        let badgeSize = geometry.cellSize * 0.32
        switch piece.kind {
        case .standard, .heavy:
            break
        case .fragile:
            let crack = SKLabelNode(text: piece.crackLevel >= 1 ? "✕" : "·")
            crack.fontName = "AvenirNext-Heavy"
            crack.fontSize = badgeSize
            crack.fontColor = renderColor
            crack.position = tail
            crack.zPosition = 2
            addChild(crack)
            kindBadges.append(crack)
        case .frozen:
            addOverlay(symbol: "❄", at: tail, size: badgeSize, color: renderColor)
        case .double:
            if let second = piece.secondaryDirection {
                let head = geometry.point(for: piece.headCell)
                let arrow = SKLabelNode(text: arrowGlyph(for: second))
                arrow.fontName = "AvenirNext-Heavy"
                arrow.fontSize = badgeSize
                arrow.fontColor = renderColor
                let unit = second.spriteVector
                arrow.position = CGPoint(
                    x: head.x + unit.dx * geometry.cellSize * 0.35,
                    y: head.y + unit.dy * geometry.cellSize * 0.35
                )
                arrow.zPosition = 2
                addChild(arrow)
                kindBadges.append(arrow)
            }
        case .lockedLock:
            addOverlay(symbol: "🔒", at: tail, size: badgeSize, color: renderColor)
            addGroupMarker(at: tail, size: badgeSize)
        case .lockedKey:
            addOverlay(symbol: "🔑", at: tail, size: badgeSize, color: renderColor)
            addGroupMarker(at: tail, size: badgeSize)
        case .bomb:
            addOverlay(symbol: "✸", at: tail, size: badgeSize * 1.2, color: renderColor)
        case .chain:
            addOverlay(symbol: "⛓", at: tail, size: badgeSize, color: renderColor)
        }
    }

    private func addOverlay(symbol: String, at point: CGPoint, size: CGFloat, color: UIColor) {
        let label = SKLabelNode(text: symbol)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = point
        label.zPosition = 2
        addChild(label)
        kindBadges.append(label)
    }

    /// Matching keys and locks previously depended on their tint alone.
    /// A shared number makes every pair identifiable with color filters off.
    private func addGroupMarker(at point: CGPoint, size: CGFloat) {
        guard let group = piece.colorGroup else { return }
        let label = SKLabelNode(text: "\(group)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = max(7, size * 0.58)
        label.fontColor = lineColor
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: point.x + size * 0.48, y: point.y - size * 0.36)
        label.zPosition = 3
        addChild(label)
        kindBadges.append(label)
    }

    private func arrowGlyph(for direction: Direction) -> String {
        switch direction {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        }
    }

    // MARK: - state

    enum DisplayState {
        case normal, blocked, hint, leaving, areaHint, ghost
    }

    func apply(_ state: DisplayState) {
        switch state {
        case .normal:
            setDisplayedColor(renderColor)
            mainShape.alpha = 1.0
            contrastShape.alpha = 1.0
            clearStateBadge()
        case .blocked:
            setDisplayedColor(blockedColor)
            showStateBadge("!", color: blockedColor)
        case .hint:
            setDisplayedColor(hintColor)
            mainShape.alpha = 1.0
            contrastShape.alpha = 1.0
            showStateBadge("✓", color: hintColor)
        case .leaving:
            isLeaving = true
        case .areaHint:
            setDisplayedColor(hintColor.withAlphaComponent(0.6))
            showStateBadge("✓", color: hintColor)
        case .ghost:
            mainShape.alpha = 0.4
            contrastShape.alpha = 0.4
        }
    }

    private func setDisplayedColor(_ color: UIColor) {
        mainShape.strokeColor = color
    }

    private func showStateBadge(_ symbol: String, color: UIColor) {
        clearStateBadge()
        let label = SKLabelNode(text: symbol)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = min(18, max(8, geometry.cellSize * 0.46))
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = geometry.point(for: piece.headCell)
        label.zPosition = 4
        addChild(label)
        stateBadge = label
    }

    private func clearStateBadge() {
        stateBadge?.removeFromParent()
        stateBadge = nil
    }

    func setCrackVisual(level: Int) {
        piece.crackLevel = level
        addKindBadges()
        if level == 0 {
            mainShape.alpha = 1.0
            contrastShape.alpha = 1.0
        } else {
            let alpha = max(0.5, 1.0 - 0.25 * CGFloat(level))
            mainShape.alpha = alpha
            contrastShape.alpha = alpha
        }
    }

    // MARK: - animations

    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled
        guard enabled else { return }

        // These are visual-only and can be stopped safely. Fly-out and blocked
        // feedback own gameplay completions, so let a current short run finish.
        removeAction(forKey: "hint")
        removeAction(forKey: "ghost")
        setScale(1)
        if blockedCompletion == nil, flyOutCompletion == nil {
            apply(.normal)
        }
    }

    /// Shake + flash red to indicate a failed tap. Optionally amplified
    /// (for fragile pieces) to telegraph extra danger.
    func runBlockedFeedback(amplified: Bool = false, onComplete: @escaping () -> Void) {
        finishBlockedFeedback()
        blockedCompletion = onComplete
        apply(.blocked)
        let reset = SKAction.run { [weak self] in
            self?.apply(.normal)
            self?.finishBlockedFeedback()
        }
        if reduceMotion {
            run(.sequence([.wait(forDuration: 0.18), reset]), withKey: "blocked")
        } else {
            let dx = max(4, geometry.cellSize * (amplified ? 0.30 : 0.18))
            let shake = SKAction.sequence([
                .moveBy(x: -dx, y: 0, duration: 0.04),
                .moveBy(x: dx * 2, y: 0, duration: 0.08),
                .moveBy(x: -dx, y: 0, duration: 0.04),
            ])
            run(.sequence([shake, .wait(forDuration: 0.12), reset]), withKey: "blocked")
        }
    }

    /// Gentle pulse used to surface a hint piece.
    func runHintFeedback() {
        apply(.hint)
        let reset = SKAction.run { [weak self] in self?.apply(.normal) }
        guard !reduceMotion else {
            run(.sequence([.wait(forDuration: 0.7), reset]), withKey: "hint")
            return
        }
        let up = SKAction.scale(to: 1.08, duration: 0.18)
        up.timingMode = .easeOut
        let down = SKAction.scale(to: 1.0, duration: 0.18)
        down.timingMode = .easeIn
        run(.sequence([up, down, up, down, reset]), withKey: "hint")
    }

    /// Ghost-arrow preview for multi-level hints (level 3).
    /// Drops a faint duplicate of the piece in a position offset by one step
    /// along its direction. The duplicate auto-fades.
    func runGhostStep() {
        apply(.ghost)
        let restore = SKAction.run { [weak self] in self?.apply(.normal) }
        run(.sequence([.wait(forDuration: 1.0), restore]), withKey: "ghost")
    }

    /// Exit animation for a whole maze-arrow piece.
    ///
    /// Keep this cheap: it runs on the main SpriteKit thread after every tap.
    /// Pre-rendering texture frames here causes gesture-gate timeouts on dense
    /// boards, especially with the larger generated campaign levels.
    func runFlyOut(distanceCells: Int, onComplete: @escaping () -> Void) {
        finishFlyOut()
        flyOutCompletion = onComplete
        apply(.leaving)

        if reduceMotion {
            let complete = SKAction.run { [weak self] in self?.finishFlyOut() }
            run(
                .sequence([.fadeOut(withDuration: 0.12), complete]),
                withKey: "fly-prep"
            )
            return
        }

        kindBadges.forEach { $0.run(.fadeOut(withDuration: 0.12)) }

        // Tiny perpendicular tremor — a brief "shiver" before the piece flies.
        // Perpendicular to the travel direction so it reads as anticipation
        // without looking like a jump or a squash.
        let unit = piece.direction.spriteVector
        let perpX: CGFloat = -CGFloat(unit.dy)
        let perpY: CGFloat =  CGFloat(unit.dx)
        let amp: CGFloat = 1.8
        let dt: TimeInterval = 0.035
        let tremor = SKAction.sequence([
            .moveBy(x: perpX * amp,      y: perpY * amp,      duration: dt),
            .moveBy(x: -perpX * amp * 2, y: -perpY * amp * 2, duration: dt),
            .moveBy(x: perpX * amp * 2,  y: perpY * amp * 2,  duration: dt),
            .moveBy(x: -perpX * amp,     y: -perpY * amp,     duration: dt),
        ])

        run(.sequence([tremor, .run { [weak self] in
            self?.performSnakeFlyOut(distanceCells: distanceCells)
        }]), withKey: "fly-prep")
    }

    private func performSnakeFlyOut(distanceCells: Int) {
        let cellSize = geometry.cellSize
        let unit = piece.direction.spriteVector
        let bodyPoints = Self.simplifiedRenderCells(piece.cells).map { geometry.point(for: $0) }
        guard let head = bodyPoints.last else { finishFlyOut(); return }

        let pieceLength = max(cellSize, CGFloat(piece.cells.count - 1) * cellSize)
        let exitLength = CGFloat(distanceCells) * cellSize + pieceLength + cellSize
        let extendedEnd = CGPoint(
            x: head.x + unit.dx * exitLength,
            y: head.y + unit.dy * exitLength
        )
        let sampler = RenderPathSampler(points: bodyPoints + [extendedEnd])
        let duration = TimeInterval(min(0.58, max(0.28, 0.18 + 0.018 * Double(piece.cells.count))))
        let headAngle = piece.direction.spriteAngle
        let chevronHalf = self.chevronHalf
        let exitAdvance = exitLength

        let snake = SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let self else { return }
            let raw = min(1, max(0, elapsed / CGFloat(duration)))
            let eased = raw * raw
            let advance = eased * exitAdvance
            let visibleBody = Self.cleanedBody(
                sampler.points(from: advance, to: advance + pieceLength)
            )
            self.setRenderPath(Self.buildPath(
                body: visibleBody,
                headAngle: headAngle,
                chevronHalf: chevronHalf
            ))
        }
        let fade = SKAction.fadeOut(withDuration: duration * 0.24)
        fade.timingMode = .easeIn
        let complete = SKAction.run { [weak self] in
            self?.finishFlyOut()
        }
        mainShape.run(.sequence([
            .group([
                snake,
                .sequence([.wait(forDuration: duration * 0.76), fade])
            ]),
            complete
        ]), withKey: "fly")
        contrastShape.run(.sequence([
            .wait(forDuration: duration * 0.76),
            .fadeOut(withDuration: duration * 0.24)
        ]), withKey: "fly-contrast")
    }

    /// Stops every action owned by this piece and resolves gameplay callbacks
    /// exactly once. Keeping callbacks outside SKAction makes interruption
    /// deterministic and releases captured model state immediately.
    func interruptActions(completingPendingOperations: Bool) {
        removeActionsRecursively(from: self)

        let blocked = blockedCompletion
        let flyOut = flyOutCompletion
        blockedCompletion = nil
        flyOutCompletion = nil

        if completingPendingOperations {
            blocked?()
            flyOut?()
        }
    }

    private func finishBlockedFeedback() {
        let completion = blockedCompletion
        blockedCompletion = nil
        completion?()
    }

    private func finishFlyOut() {
        let completion = flyOutCompletion
        flyOutCompletion = nil
        completion?()
    }

    private func removeActionsRecursively(from node: SKNode) {
        node.removeAllActions()
        for child in node.children {
            removeActionsRecursively(from: child)
        }
    }

    /// Translucent preview of the head's exit trajectory along the arrow
    /// direction. Stops at the collision cell, if any, and drops a red dot
    /// at the blocker so the player sees WHY they're blocked.
    func showPathPreview(board: Board, blocked: GridPoint?) {
        children.filter { $0.name == "preview" }.forEach { $0.removeFromParent() }

        let unit = piece.direction.spriteVector
        let headPoint = geometry.point(for: piece.headCell)
        let endPoint: CGPoint
        if let blocked {
            endPoint = geometry.point(for: blocked)
        } else {
            let cells = MoveValidator.exitDistanceInCells(for: piece, board: board)
            let len = CGFloat(cells) * geometry.cellSize * 0.6
            endPoint = CGPoint(x: headPoint.x + unit.dx * len, y: headPoint.y + unit.dy * len)
        }

        let preview = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: headPoint)
        p.addLine(to: endPoint)
        preview.path = p
        preview.strokeColor = (blocked == nil ? renderColor : blockedColor).withAlphaComponent(0.4)
        preview.lineWidth = strokeWidth * 0.6
        preview.lineCap = .round
        preview.lineJoin = .round
        preview.alpha = 0
        preview.zPosition = -1
        preview.name = "preview"
        addChild(preview)

        let actions: [SKAction] = [.fadeIn(withDuration: 0.10)]

        if blocked != nil {
            let dot = SKShapeNode(circleOfRadius: geometry.cellSize * 0.18)
            dot.fillColor = blockedColor
            dot.strokeColor = blockedColor.withAlphaComponent(0.6)
            dot.lineWidth = 2
            dot.position = endPoint
            dot.alpha = 0
            dot.zPosition = 0
            dot.name = "preview"
            addChild(dot)

            // A two-tone X stays legible on both dark and light boards and
            // explains the blocker without relying on the red dot alone.
            let crossPath = CGMutablePath()
            let half = geometry.cellSize * 0.09
            crossPath.move(to: CGPoint(x: -half, y: -half))
            crossPath.addLine(to: CGPoint(x: half, y: half))
            crossPath.move(to: CGPoint(x: -half, y: half))
            crossPath.addLine(to: CGPoint(x: half, y: -half))
            let crossOutline = SKShapeNode(path: crossPath)
            crossOutline.strokeColor = .white
            crossOutline.lineWidth = 4
            crossOutline.lineCap = .round
            crossOutline.zPosition = 1
            dot.addChild(crossOutline)
            let cross = SKShapeNode(path: crossPath)
            cross.strokeColor = .black
            cross.lineWidth = 1.5
            cross.lineCap = .round
            cross.zPosition = 2
            dot.addChild(cross)
            dot.run(.fadeIn(withDuration: 0.10))
        }

        preview.run(.sequence(actions + [
            .wait(forDuration: 0.45),
            .fadeOut(withDuration: 0.15),
            .removeFromParent()
        ]))
    }

    func clearPreview() {
        children.filter { $0.name == "preview" }.forEach { $0.removeFromParent() }
    }

    // MARK: - path construction

    private static func simplifiedRenderCells(_ cells: [GridPoint]) -> [GridPoint] {
        guard cells.count > 2 else { return cells }

        var simplified: [GridPoint] = [cells[0]]
        for index in 1..<(cells.count - 1) {
            let previous = cells[index - 1]
            let current = cells[index]
            let next = cells[index + 1]
            let dx1 = current.x - previous.x
            let dy1 = current.y - previous.y
            let dx2 = next.x - current.x
            let dy2 = next.y - current.y

            if dx1 == dx2 && dy1 == dy2 {
                continue
            }
            simplified.append(current)
        }
        simplified.append(cells[cells.count - 1])
        return simplified
    }

    /// Removes near-duplicate and collinear intermediate points from a sampled
    /// body polyline. The fly-out sampler emits the original head vertex (and
    /// vertices the piece is passing through) even when they lie exactly on a
    /// straight run — SKShapeNode's round-join tessellation renders such
    /// degenerate joins as flickering triangular notches in the stroke.
    private static func cleanedBody(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let epsilon: CGFloat = 0.5
        var result: [CGPoint] = [points[0]]
        for point in points.dropFirst() {
            let last = result[result.count - 1]
            if hypot(point.x - last.x, point.y - last.y) < epsilon {
                // Keep the true endpoint so the chevron stays anchored.
                result[result.count - 1] = point
                continue
            }
            while result.count >= 2 {
                let a = result[result.count - 2]
                let b = result[result.count - 1]
                let cross = (b.x - a.x) * (point.y - b.y) - (b.y - a.y) * (point.x - b.x)
                let dot = (b.x - a.x) * (point.x - b.x) + (b.y - a.y) * (point.y - b.y)
                if abs(cross) < epsilon && dot > 0 {
                    result.removeLast()
                } else {
                    break
                }
            }
            result.append(point)
        }
        return result
    }

    private static func buildPath(
        body: [CGPoint],
        headAngle: CGFloat,
        chevronHalf: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        guard let first = body.first else { return path }
        path.move(to: first)
        for p in body.dropFirst() {
            path.addLine(to: p)
        }
        guard let head = body.last else { return path }

        let s = chevronHalf
        let c = cos(headAngle)
        let si = sin(headAngle)
        let leftLocal  = CGPoint(x: -s, y:  s)
        let rightLocal = CGPoint(x: -s, y: -s)
        let leftP = CGPoint(
            x: head.x + leftLocal.x * c - leftLocal.y * si,
            y: head.y + leftLocal.x * si + leftLocal.y * c
        )
        let rightP = CGPoint(
            x: head.x + rightLocal.x * c - rightLocal.y * si,
            y: head.y + rightLocal.x * si + rightLocal.y * c
        )
        path.move(to: leftP)
        path.addLine(to: head)
        path.addLine(to: rightP)
        return path
    }
}

private struct RenderPathSampler {
    struct Segment {
        let start: CGPoint
        let end: CGPoint
        let length: CGFloat
        let cumulative: CGFloat
    }

    let segments: [Segment]
    let totalLength: CGFloat

    init(points: [CGPoint]) {
        var result: [Segment] = []
        var cumulative: CGFloat = 0
        for index in 1..<points.count {
            let start = points[index - 1]
            let end = points[index]
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length > 0 else { continue }
            result.append(Segment(
                start: start,
                end: end,
                length: length,
                cumulative: cumulative
            ))
            cumulative += length
        }
        self.segments = result
        self.totalLength = cumulative
    }

    func point(at distance: CGFloat) -> CGPoint {
        guard !segments.isEmpty else { return .zero }
        if distance <= 0 { return segments[0].start }
        if distance >= totalLength { return segments[segments.count - 1].end }

        for segment in segments where distance <= segment.cumulative + segment.length {
            let t = (distance - segment.cumulative) / segment.length
            return CGPoint(
                x: segment.start.x + (segment.end.x - segment.start.x) * t,
                y: segment.start.y + (segment.end.y - segment.start.y) * t
            )
        }
        return segments[segments.count - 1].end
    }

    func points(from start: CGFloat, to end: CGFloat) -> [CGPoint] {
        guard start < end else { return [point(at: start)] }
        var output = [point(at: start)]

        for segment in segments {
            let vertexDistance = segment.cumulative + segment.length
            if vertexDistance > start + 0.0001 && vertexDistance < end - 0.0001 {
                output.append(segment.end)
            }
        }

        output.append(point(at: end))
        return output
    }
}
