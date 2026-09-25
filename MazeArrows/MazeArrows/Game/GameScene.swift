//
//  GameScene.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  SpriteKit scene. Owns the live `Board`, renders the maze pieces and
//  obstacles, and forwards events to a thin protocol the SwiftUI ViewModel
//  implements.
//

import SpriteKit
import UIKit

protocol GameSceneDelegate: AnyObject {
    /// A piece was tapped. Scene asks the model whether the move is valid
    /// and what to do next.
    func sceneDidTapPiece(_ pieceId: String)
    /// User is long-pressing a piece. Scene wants to show a preview if enabled.
    func sceneDidLongPressPiece(_ pieceId: String)
    /// User released the long press.
    func sceneDidEndLongPress()
    /// User swiped a `.double`-kind piece. Direction is the swipe direction.
    func sceneDidSwipePiece(_ pieceId: String, direction: Direction)
}

extension GameSceneDelegate {
    func sceneDidSwipePiece(_ pieceId: String, direction: Direction) {}
}

final class GameScene: SKScene {

    weak var sceneDelegate: GameSceneDelegate?
    var accessibilityElementsDidChange: (() -> Void)?
    var didPrepareForDisplay: (() -> Void)?

    private(set) var board: Board
    private var geometry: BoardGeometry
    private var theme: GameTheme
    private let piecePalette: [PieceGroupPaletteColor]
    private let showsArrowOutlines: Bool
    private let arrowOutlineColor: PieceGroupPaletteColor
    private var reduceMotion: Bool
    private var nodes: [String: ArrowPieceNode] = [:]
    private var obstacleNodes: [String: ObstacleNode] = [:]
    private let boardLayer = SKNode()
    private let obstacleLayer = SKNode()
    private let pieceLayer = SKNode()
    private let fxLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private var longPressGesture: UILongPressGestureRecognizer?
    private var swipeRecognizers: [UISwipeGestureRecognizer] = []
    private var tapGesture: UITapGestureRecognizer?
    private var panGesture: UIPanGestureRecognizer?
    private var pinchGesture: UIPinchGestureRecognizer?
    private var pinchStartScale: CGFloat = 1
    private let minimumPieceTouchTarget: CGFloat = 44
    /// Cached scenes are emptied when detached so no SKAction tree keeps
    /// visual nodes or gameplay callbacks alive off-screen. Rebuild on reuse.
    private var needsRenderAfterInterruption = true

    init(
        level: Level,
        theme: GameTheme,
        size: CGSize,
        showsArrowOutlines: Bool = false,
        arrowOutlineColor: PieceGroupPaletteColor = .init(red: 0.12, green: 0.12, blue: 0.16),
        reduceMotion: Bool = false
    ) {
        self.board = level.makeBoard()
        self.theme = theme
        self.piecePalette = level.piecePalette
        self.showsArrowOutlines = showsArrowOutlines
        self.arrowOutlineColor = arrowOutlineColor
        self.reduceMotion = reduceMotion
        self.geometry = BoardGeometry(
            boardWidth: level.width,
            boardHeight: level.height,
            availableSize: size
        )
        super.init(size: size)
        self.scaleMode = .resizeFill
        self.backgroundColor = theme.boardBackground.uiColor
        configureLayers()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is unavailable") }

    // MARK: - lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if needsRenderAfterInterruption {
            renderAll()
            needsRenderAfterInterruption = false
        }
        // Pinch-to-zoom needs both fingers delivered to the recognizers.
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        // Keep SpriteKit's backing surface pinned to the display's native
        // scale. Any mismatch is magnified along with the camera transform.
        let displayScale = view.window?.screen.scale ?? UIScreen.main.scale
        if view.contentScaleFactor != displayScale {
            view.contentScaleFactor = displayScale
        }
        // A level always opens with the whole board visible — zooming is the
        // player's explicit choice (the scene may be cached from a previous
        // visit with an old camera state).
        resetCamera()
        attachLongPressRecognizer(to: view)
        attachSwipeRecognizers(to: view)
        attachCameraRecognizers(to: view)
        #if DEBUG
        applyScreenshotCaptureStateIfNeeded()
        #endif
        refreshAccessibilityElements()
        didPrepareForDisplay?()
        #if DEBUG
        if ScreenshotCaptureConfiguration.current?.scene.usesGameScene == true {
            ScreenshotCaptureSignal.markReady()
        }
        #endif

        #if DEBUG
        // Simulator can't pinch via UI automation — start zoomed-in to
        // exercise the camera path (pan, clamping, hit-testing) directly.
        if ProcessInfo.processInfo.arguments.contains("-debugMaximumZoom") {
            cameraNode.setScale(minCameraScale)
            clampCamera()
            updateArrowRenderScale(for: cameraNode.xScale)
        } else if ProcessInfo.processInfo.arguments.contains("-debugZoom") {
            cameraNode.setScale(max(minCameraScale, 0.5))
            clampCamera()
            updateArrowRenderScale(for: cameraNode.xScale)
        }
        #endif

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--debug-autoplay") {
            let pieces = board.pieces
            var delay: TimeInterval = 0.6
            for piece in pieces {
                let work = SKAction.run { [weak self] in
                    self?.sceneDelegate?.sceneDidTapPiece(piece.id)
                }
                self.run(.sequence([.wait(forDuration: delay), work]))
                delay += 0.6
            }
        }
        #endif
    }

    #if DEBUG
    /// Makes the solver's genuinely available move unmistakable in the
    /// mechanic screenshot while leaving the board and move rules untouched.
    private func applyScreenshotCaptureStateIfNeeded() {
        guard ScreenshotCaptureConfiguration.current?.scene == .mechanic,
              let piece = LevelSolver.nextHintPiece(board: board),
              let node = nodes[piece.id]
        else { return }

        node.apply(.hint)
        node.showPathPreview(board: board, blocked: nil)
    }
    #endif

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        if let lp = longPressGesture {
            view.removeGestureRecognizer(lp)
            longPressGesture = nil
        }
        swipeRecognizers.forEach { view.removeGestureRecognizer($0) }
        swipeRecognizers.removeAll()
        for recognizer in [tapGesture, panGesture, pinchGesture].compactMap({ $0 }) {
            view.removeGestureRecognizer(recognizer)
        }
        tapGesture = nil
        panGesture = nil
        pinchGesture = nil

        // Detaching ends the visible game session. Pending gameplay callbacks
        // must be discarded, otherwise an interrupted fly-out can record a
        // victory or schedule a chained move after the player has left.
        clearRenderedNodes(completingPendingOperations: false)
        needsRenderAfterInterruption = true
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1, size.height > 1 else { return }
        rebuildGeometry(for: size)
    }

    // MARK: - configuration

    private func configureLayers() {
        boardLayer.zPosition = 0
        obstacleLayer.zPosition = 5
        pieceLayer.zPosition = 10
        fxLayer.zPosition = 20
        addChild(boardLayer)
        addChild(obstacleLayer)
        addChild(pieceLayer)
        addChild(fxLayer)
        addChild(cameraNode)
        camera = cameraNode
        resetCamera()
    }

    private func renderAll(completingPendingOperations: Bool = true) {
        clearRenderedNodes(completingPendingOperations: completingPendingOperations)
        drawBoardBackground()
        for obstacle in board.obstacles {
            let node = ObstacleNode(
                obstacle: obstacle,
                geometry: geometry,
                theme: theme,
                reduceMotion: reduceMotion
            )
            obstacleLayer.addChild(node)
            obstacleNodes[obstacle.id] = node
        }
        for piece in board.pieces {
            let node = makeNode(for: piece)
            pieceLayer.addChild(node)
            nodes[piece.id] = node
        }
        refreshAccessibilityElements()
    }

    /// Resolves model-facing callbacks before tearing down the SpriteKit tree.
    /// `removeAllChildren()` alone is insufficient: actions on descendants can
    /// retain their closure captures until SpriteKit releases the detached tree.
    private func clearRenderedNodes(completingPendingOperations: Bool) {
        // Callbacks are allowed to mutate the dictionaries, so iterate snapshots.
        let currentPieceNodes = Array(nodes.values)
        let currentObstacleNodes = Array(obstacleNodes.values)

        currentPieceNodes.forEach {
            $0.interruptActions(completingPendingOperations: completingPendingOperations)
        }
        currentObstacleNodes.forEach {
            $0.interruptActions(completingPendingOperation: completingPendingOperations)
        }

        // A completion may have spawned FX (for example the victory burst), so
        // sweep the complete hierarchy after all model callbacks have run.
        removeActionsRecursively(from: self)
        boardLayer.removeAllChildren()
        obstacleLayer.removeAllChildren()
        pieceLayer.removeAllChildren()
        fxLayer.removeAllChildren()
        nodes.removeAll(keepingCapacity: false)
        obstacleNodes.removeAll(keepingCapacity: false)
    }

    private func removeActionsRecursively(from node: SKNode) {
        node.removeAllActions()
        for child in node.children {
            removeActionsRecursively(from: child)
        }
    }

    private func drawBoardBackground() {
        let cornerRadius = min(24, max(8, geometry.cellSize * 0.7))
        let bg = SKShapeNode(
            rectOf: geometry.boardSize(),
            cornerRadius: cornerRadius
        )
        bg.position = CGPoint(
            x: geometry.origin.x + geometry.boardSize().width / 2,
            y: geometry.origin.y + geometry.boardSize().height / 2
        )
        bg.fillColor = theme.boardBackground.uiColor
        bg.strokeColor = .clear
        bg.lineWidth = 0
        bg.zPosition = 0
        boardLayer.addChild(bg)

        let dotColor = theme.boardGrid.uiColor
        let dotRadius = usesDensePhotoRendering
            ? geometry.cellSize * 0.045
            : max(0.55, min(1.15, geometry.cellSize * 0.045))
        let dotDiameter = dotRadius * 2
        let dotsPath = CGMutablePath()
        for x in 0..<board.width {
            for y in 0..<board.height {
                let center = geometry.point(for: GridPoint(x: x, y: y))
                dotsPath.addEllipse(in: CGRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotDiameter,
                    height: dotDiameter
                ))
            }
        }

        // One vector node replaces width × height individual SKShapeNodes.
        // This keeps the dots sharp while zooming and reduces both node-tree
        // traversal and SpriteKit draw-call overhead on dense photo boards.
        let grid = SKShapeNode(path: dotsPath)
        grid.name = "board-grid"
        grid.fillColor = dotColor
        grid.strokeColor = .clear
        grid.lineWidth = 0
        grid.zPosition = 1
        boardLayer.addChild(grid)
    }

    private func makeNode(for piece: ArrowPiece) -> ArrowPieceNode {
        let node = ArrowPieceNode(
            piece: piece,
            geometry: geometry,
            lineColor: theme.pieceStroke.uiColor,
            piecePalette: piecePalette,
            highlightColor: theme.danger.uiColor,
            hintColor: theme.success.uiColor,
            outlineColor: UIColor(
                red: arrowOutlineColor.red,
                green: arrowOutlineColor.green,
                blue: arrowOutlineColor.blue,
                alpha: 1
            ),
            useGlow: theme.pieceGlow,
            showsOutline: showsArrowOutlines,
            reduceMotion: reduceMotion
        )
        node.setCameraRenderScale(arrowRenderScale(for: cameraNode.xScale))
        return node
    }

    /// Applies a board mutation without rebuilding the unchanged SpriteKit
    /// hierarchy. IDs are stable model identity; content equality decides
    /// whether an existing node can be reused or must be replaced.
    private func synchronizeRenderedBoard(with newBoard: Board) {
        let newPieceIDs = Set(newBoard.pieces.map(\.id))
        let removedPieceIDs = nodes.keys.filter { !newPieceIDs.contains($0) }
        for id in removedPieceIDs {
            // `performFlyOut` removes the model value before its animation
            // finishes. Keep that intentional transient node until completion.
            guard nodes[id]?.isLeaving != true else { continue }
            removeRenderedPiece(id: id)
        }

        for piece in newBoard.pieces {
            if let node = nodes[piece.id], node.piece == piece {
                continue
            }
            removeRenderedPiece(id: piece.id)
            let node = makeNode(for: piece)
            pieceLayer.addChild(node)
            nodes[piece.id] = node
        }

        let newObstacleIDs = Set(newBoard.obstacles.map(\.id))
        let removedObstacleIDs = obstacleNodes.keys.filter { !newObstacleIDs.contains($0) }
        for id in removedObstacleIDs {
            // Destruction also removes its model value first. A simultaneous
            // piece mutation must not cut the visual effect short.
            guard obstacleNodes[id]?.isBeingDestroyed != true else { continue }
            removeRenderedObstacle(id: id)
        }

        for obstacle in newBoard.obstacles {
            if let node = obstacleNodes[obstacle.id], node.obstacle == obstacle {
                continue
            }
            removeRenderedObstacle(id: obstacle.id)
            let node = ObstacleNode(
                obstacle: obstacle,
                geometry: geometry,
                theme: theme,
                reduceMotion: reduceMotion
            )
            obstacleLayer.addChild(node)
            obstacleNodes[obstacle.id] = node
        }
        refreshAccessibilityElements()
    }

    private func removeRenderedPiece(id: String) {
        guard let node = nodes.removeValue(forKey: id) else { return }
        node.interruptActions(completingPendingOperations: false)
        node.removeFromParent()
    }

    private func removeRenderedObstacle(id: String) {
        guard let node = obstacleNodes.removeValue(forKey: id) else { return }
        node.interruptActions(completingPendingOperation: false)
        node.removeFromParent()
    }

    private func rebuildGeometry(for size: CGSize) {
        self.geometry = BoardGeometry(
            boardWidth: board.width,
            boardHeight: board.height,
            availableSize: size
        )
        resetCamera()
        renderAll()
    }

    // MARK: - public API used by ViewModel

    /// Stops SpriteKit actions and releases their gameplay completions without
    /// invoking them. The cached scene can render itself again if reused.
    func suspendGameplay() {
        sceneDelegate = nil
        clearRenderedNodes(completingPendingOperations: false)
        needsRenderAfterInterruption = true
    }

    /// Incremental model update used by Undo and gameplay side effects.
    /// Unchanged nodes, active FX and the player's camera position survive.
    func setBoard(_ newBoard: Board) {
        let dimensionsChanged = board.width != newBoard.width || board.height != newBoard.height
        self.board = newBoard

        guard !dimensionsChanged else {
            geometry = BoardGeometry(
                boardWidth: newBoard.width,
                boardHeight: newBoard.height,
                availableSize: size
            )
            resetCamera()
            renderAll(completingPendingOperations: false)
            return
        }

        synchronizeRenderedBoard(with: newBoard)
    }

    /// Explicit session reset. Unlike an incremental mutation, this clears
    /// transient actions/FX and returns the camera to its initial position.
    func resetBoard(_ newBoard: Board) {
        self.board = newBoard
        geometry = BoardGeometry(
            boardWidth: newBoard.width,
            boardHeight: newBoard.height,
            availableSize: size
        )
        resetCamera()
        renderAll(completingPendingOperations: false)
    }

    func updateTheme(_ newTheme: GameTheme) {
        self.theme = newTheme
        self.backgroundColor = newTheme.boardBackground.uiColor
        renderAll()
    }

    /// Updates motion preferences without rebuilding the scene or resetting
    /// the live board. Existing looping/visual-only effects stop immediately;
    /// gameplay-critical actions finish their short current operation.
    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled
        nodes.values.forEach { $0.setReduceMotion(enabled) }
        obstacleNodes.values.forEach { $0.setReduceMotion(enabled) }

        if enabled {
            [boardLayer, obstacleLayer, pieceLayer].forEach {
                $0.removeAction(forKey: "shake")
                $0.position = .zero
            }
            fxLayer.removeAllActions()
            fxLayer.removeAllChildren()
        }
    }

    func performBlocked(pieceId: String, amplified: Bool = false, onComplete: @escaping () -> Void) {
        guard let node = nodes[pieceId] else { onComplete(); return }
        runFieldFlash(around: node.position)
        node.runBlockedFeedback(amplified: amplified, onComplete: onComplete)
    }

    /// Mild whole-field tremor on a blocked tap. Communicates "ouch" without
    /// being disorienting. Tied to the world layers, not the camera.
    func runFieldShake() {
        guard !reduceMotion else { return }
        let dx: CGFloat = 5
        let shake = SKAction.sequence([
            .moveBy(x: -dx, y: 0, duration: 0.04),
            .moveBy(x: dx * 2, y: 0, duration: 0.06),
            .moveBy(x: -dx * 1.5, y: 0, duration: 0.06),
            .moveBy(x: dx * 0.5, y: 0, duration: 0.04),
        ])
        [boardLayer, obstacleLayer, pieceLayer].forEach {
            $0.removeAction(forKey: "shake")
            $0.run(shake, withKey: "shake")
        }
    }

    /// Micro-flash around the blocker — a quick translucent ring.
    private func runFieldFlash(around point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: geometry.cellSize * 0.7)
        ring.position = point
        ring.fillColor = .clear
        ring.strokeColor = theme.danger.uiColor.withAlphaComponent(0.55)
        ring.lineWidth = 3
        ring.zPosition = 22
        fxLayer.addChild(ring)
        let feedback: SKAction = reduceMotion
            ? .fadeOut(withDuration: 0.12)
            : .group([
                .scale(to: 1.8, duration: 0.32),
                .fadeOut(withDuration: 0.32)
            ])
        ring.run(.sequence([feedback, .removeFromParent()]))
        runFieldShake()
    }

    func performFlyOut(pieceId: String, onComplete: @escaping () -> Void) {
        guard let node = nodes[pieceId],
              let piece = board.pieces.first(where: { $0.id == pieceId }) else {
            onComplete(); return
        }
        board.removePiece(id: pieceId)
        refreshAccessibilityElements()
        let distance = MoveValidator.exitDistanceInCells(for: piece, board: board) + 1
        // The action is retained by `node`; capturing that same node strongly
        // here would create node -> action -> completion -> node until the
        // animation finishes (or forever if SpriteKit interrupts it).
        node.runFlyOut(distanceCells: distance) { [weak self, weak node] in
            node?.removeFromParent()
            self?.nodes[pieceId] = nil
            onComplete()
        }
    }

    /// Visual-only: spawn a quick explosion ring at a cell. Used when bombs
    /// destroy something or when a fragile piece breaks.
    func runExplosion(at cell: GridPoint, color: UIColor? = nil) {
        let p = geometry.point(for: cell)
        let ring = SKShapeNode(circleOfRadius: geometry.cellSize * 0.4)
        ring.position = p
        ring.fillColor = .clear
        ring.strokeColor = color ?? theme.danger.uiColor
        ring.lineWidth = 4
        ring.zPosition = 25
        fxLayer.addChild(ring)
        let ringFeedback: SKAction = reduceMotion
            ? .fadeOut(withDuration: 0.12)
            : .group([
                .scale(to: 2.2, duration: 0.35),
                .fadeOut(withDuration: 0.35)
            ])
        ring.run(.sequence([ringFeedback, .removeFromParent()]))
        guard !reduceMotion else { return }
        // 6 little particles
        for i in 0..<6 {
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.position = p
            dot.fillColor = color ?? theme.danger.uiColor
            dot.strokeColor = .clear
            dot.zPosition = 25
            fxLayer.addChild(dot)
            let angle = CGFloat(i) / 6 * .pi * 2
            let dx = cos(angle) * geometry.cellSize * 0.9
            let dy = sin(angle) * geometry.cellSize * 0.9
            dot.run(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: 0.36),
                    .fadeOut(withDuration: 0.36)
                ]),
                .removeFromParent()
            ]))
        }
    }

    func removeObstacle(id: String) {
        guard let node = obstacleNodes[id] else { return }
        node.runDestroy { [weak self] in
            self?.obstacleNodes[id] = nil
        }
        board.removeObstacle(id: id)
        refreshAccessibilityElements()
    }

    func updatePieceCrack(id: String, level: Int) {
        nodes[id]?.setCrackVisual(level: level)
        board.updatePiece(id: id) { $0.crackLevel = level }
        refreshAccessibilityElements()
    }

    func updatePieceDirection(id: String, direction: Direction) {
        guard let oldPiece = board.pieces.first(where: { $0.id == id }) else { return }
        // Rebuild the piece node since the body's last segment must align with
        // the new direction. We rotate the path simply by re-rendering.
        var updated = oldPiece
        updated.direction = direction
        board.updatePiece(id: id) { $0.direction = direction }
        let oldNode = nodes[id]
        oldNode?.interruptActions(completingPendingOperations: true)
        oldNode?.removeFromParent()
        let newNode = makeNode(for: updated)
        pieceLayer.addChild(newNode)
        nodes[id] = newNode
        refreshAccessibilityElements()
    }

    /// Trigger a "burst of celebration" particle convergence at the board
    /// center on victory. Pure FX — caller schedules the actual win overlay.
    func runVictoryBurst() {
        guard !reduceMotion else { return }
        let center = CGPoint(
            x: geometry.origin.x + geometry.boardSize().width / 2,
            y: geometry.origin.y + geometry.boardSize().height / 2
        )
        for i in 0..<24 {
            let angle = CGFloat(i) / 24 * .pi * 2
            let start = CGPoint(
                x: center.x + cos(angle) * geometry.boardSize().width * 0.4,
                y: center.y + sin(angle) * geometry.boardSize().height * 0.4
            )
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.position = start
            dot.fillColor = theme.accent2.uiColor
            dot.strokeColor = .clear
            dot.zPosition = 30
            fxLayer.addChild(dot)
            dot.run(.sequence([
                .group([
                    .move(to: center, duration: 0.65),
                    .scale(to: 0.5, duration: 0.65),
                    .fadeOut(withDuration: 0.65)
                ]),
                .removeFromParent()
            ]))
        }
    }

    func showHint(pieceId: String) {
        nodes[pieceId]?.runHintFeedback()
    }

    /// Multi-level hint:
    /// - 1: highlight the rough area (a translucent rect around the piece)
    /// - 2: highlight the specific piece (default behavior)
    /// - 3: + show a ghost arrow for the NEXT-next piece if known
    func showHint(level: Int, primary: ArrowPiece, secondary: ArrowPiece?) {
        switch level {
        case 1:
            highlightArea(around: primary)
        case 3:
            nodes[primary.id]?.runHintFeedback()
            if let secondary, let node = nodes[secondary.id] {
                node.runGhostStep()
            }
        default:
            nodes[primary.id]?.runHintFeedback()
        }
    }

    private func highlightArea(around piece: ArrowPiece) {
        let xs = piece.cells.map(\.x)
        let ys = piece.cells.map(\.y)
        let minX = (xs.min() ?? 0) - 1
        let maxX = (xs.max() ?? 0) + 1
        let minY = (ys.min() ?? 0) - 1
        let maxY = (ys.max() ?? 0) + 1
        let topLeft = geometry.point(for: GridPoint(x: minX, y: minY))
        let botRight = geometry.point(for: GridPoint(x: maxX, y: maxY))
        let rect = CGRect(
            x: min(topLeft.x, botRight.x) - geometry.cellSize * 0.5,
            y: min(topLeft.y, botRight.y) - geometry.cellSize * 0.5,
            width: abs(botRight.x - topLeft.x) + geometry.cellSize,
            height: abs(topLeft.y - botRight.y) + geometry.cellSize
        )
        let shape = SKShapeNode(rect: rect, cornerRadius: geometry.cellSize * 0.3)
        shape.strokeColor = theme.success.uiColor
        shape.lineWidth = 3
        shape.fillColor = theme.success.uiColor.withAlphaComponent(0.10)
        shape.zPosition = 28
        fxLayer.addChild(shape)
        shape.run(.sequence([
            .wait(forDuration: reduceMotion ? 0.8 : 1.5),
            .fadeOut(withDuration: reduceMotion ? 0.12 : 0.4),
            .removeFromParent()
        ]))
    }

    func showPreview(pieceId: String) {
        guard let node = nodes[pieceId],
              let piece = board.pieces.first(where: { $0.id == pieceId }) else { return }
        let blocked = MoveValidator.firstCollision(for: piece, board: board)
        node.showPathPreview(board: board, blocked: blocked)
    }

    func clearAllPreviews() {
        nodes.values.forEach { $0.clearPreview() }
    }

    // MARK: - camera: pinch zoom + pan scroll

    /// How far the player may zoom in: until a cell is ~40pt. High-detail
    /// photo levels have tiny cells, so they need substantially more than the
    /// old fixed ~7× limit before their arrowheads become readable.
    private var minCameraScale: CGFloat {
        if usesDensePhotoRendering {
            return min(1, max(1 / 16, geometry.cellSize / 40))
        }
        return min(1, max(0.15, geometry.cellSize / 40))
    }

    private var usesDensePhotoRendering: Bool {
        !piecePalette.isEmpty && geometry.cellSize < 8
    }

    private func resetCamera() {
        cameraNode.setScale(1)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        updateArrowRenderScale(for: 1)
    }

    private func arrowRenderScale(for cameraScale: CGFloat) -> CGFloat {
        let magnification = 1 / max(0.001, cameraScale)
        // Half-step buckets avoid rebuilding hundreds of short paths for tiny
        // floating-point differences while still matching the final zoom.
        return min(16, (magnification * 2).rounded(.up) / 2)
    }

    private func updateArrowRenderScale(for cameraScale: CGFloat) {
        let renderScale = arrowRenderScale(for: cameraScale)
        nodes.values.forEach { $0.setCameraRenderScale(renderScale) }
    }

    private func attachCameraRecognizers(to view: SKView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        tapGesture = tap

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        view.addGestureRecognizer(pan)
        panGesture = pan

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        view.addGestureRecognizer(pinch)
        pinchGesture = pinch
    }

    /// Taps fire on touch-UP with no movement, so panning or pinching the
    /// board can never accidentally launch an arrow.
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let view = self.view else { return }
        let scenePoint = convertPoint(fromView: recognizer.location(in: view))
        if let pieceId = hitTestPiece(at: scenePoint) {
            sceneDelegate?.sceneDidTapPiece(pieceId)
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = self.view else { return }
        let translation = recognizer.translation(in: view)
        recognizer.setTranslation(.zero, in: view)
        let scale = cameraNode.xScale
        cameraNode.position.x -= translation.x * scale
        cameraNode.position.y += translation.y * scale
        clampCamera()
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = self.view else { return }
        switch recognizer.state {
        case .began:
            pinchStartScale = cameraNode.xScale
        case .changed, .ended:
            let newScale = min(1, max(minCameraScale, pinchStartScale / recognizer.scale))
            // Keep the scene point under the fingers anchored while zooming.
            let viewPoint = recognizer.location(in: view)
            let before = convertPoint(fromView: viewPoint)
            cameraNode.setScale(newScale)
            let after = convertPoint(fromView: viewPoint)
            cameraNode.position.x += before.x - after.x
            cameraNode.position.y += before.y - after.y
            clampCamera()
            if recognizer.state == .ended {
                updateArrowRenderScale(for: newScale)
            }
        case .cancelled, .failed:
            updateArrowRenderScale(for: cameraNode.xScale)
        default:
            break
        }
    }

    /// Keeps the visible viewport inside the scene; when everything fits,
    /// the camera stays centered.
    private func clampCamera() {
        let scale = cameraNode.xScale
        let halfW = size.width * scale / 2
        let halfH = size.height * scale / 2
        cameraNode.position.x = halfW <= size.width - halfW
            ? min(max(cameraNode.position.x, halfW), size.width - halfW)
            : size.width / 2
        cameraNode.position.y = halfH <= size.height - halfH
            ? min(max(cameraNode.position.y, halfH), size.height - halfH)
            : size.height / 2
    }

    // MARK: - VoiceOver

    /// The SwiftUI accessibility overlay observes this revision callback.
    /// SpriteKit mutations are otherwise invisible to Observation because the
    /// live board is owned by the scene rather than `GameViewModel`.
    private func refreshAccessibilityElements() {
        accessibilityElementsDidChange?()
    }

    func activateAccessiblePiece(id: String, direction: Direction? = nil) -> Bool {
        guard nodes[id]?.isLeaving == false, let sceneDelegate else { return false }
        if let direction {
            sceneDelegate.sceneDidSwipePiece(id, direction: direction)
        } else {
            sceneDelegate.sceneDidTapPiece(id)
        }
        return true
    }

    func describeAccessiblePath(for pieceID: String) -> Bool {
        guard let piece = board.pieces.first(where: { $0.id == pieceID }) else { return false }
        let message: String
        if let collision = MoveValidator.firstCollision(for: piece, board: board) {
            if board.piece(at: collision) != nil {
                message = String(localized: "Path blocked by another arrow.")
            } else if let obstacle = board.obstacle(at: collision) {
                message = String(localized: "Path blocked by \(accessibilityName(for: obstacle.kind)).")
            } else {
                message = String(localized: "Path blocked.")
            }
        } else {
            message = String(localized: "Path is clear.")
        }
        UIAccessibility.post(notification: .announcement, argument: message)
        return true
    }

    private func accessibilityName(for kind: ObstacleKind) -> String {
        switch kind {
        case .wall: return String(localized: "a wall")
        case .gate: return String(localized: "a gate")
        case .portal: return String(localized: "a portal")
        case .ice: return String(localized: "ice")
        case .spring: return String(localized: "a spring")
        case .destructible: return String(localized: "a destructible block")
        }
    }

    // MARK: - touch handling

    private func hitTestPiece(at point: CGPoint) -> String? {
        // Preserve exact cell selection first, especially where neighboring
        // targets overlap on a dense board.
        if let cell = geometry.cell(at: point),
           let piece = board.piece(at: cell),
           nodes[piece.id]?.isLeaving == false {
            return piece.id
        }

        // A photo maze can render a cell far below 44 screen points. Expand
        // the logical target without changing the artwork and compensate for
        // camera zoom so it remains 44×44 in view coordinates.
        let radius = minimumPieceTouchTarget * 0.5 * cameraNode.xScale
        let maximumDistanceSquared = radius * radius
        var nearest: (pieceID: String, distanceSquared: CGFloat)?

        for piece in board.pieces where nodes[piece.id]?.isLeaving == false {
            for cell in piece.cells {
                let center = geometry.point(for: cell)
                let dx = center.x - point.x
                let dy = center.y - point.y
                let distanceSquared = dx * dx + dy * dy
                guard distanceSquared <= maximumDistanceSquared else { continue }

                if nearest == nil || distanceSquared < nearest!.distanceSquared {
                    nearest = (piece.id, distanceSquared)
                }
            }
        }

        return nearest?.pieceID
    }

    // MARK: - long press

    private func attachLongPressRecognizer(to view: SKView) {
        let lp = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        lp.minimumPressDuration = 0.25
        lp.allowableMovement = 10
        view.addGestureRecognizer(lp)
        longPressGesture = lp
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard let view = self.view else { return }
        let viewPoint = recognizer.location(in: view)
        let scenePoint = convertPoint(fromView: viewPoint)

        switch recognizer.state {
        case .began:
            if let pieceId = hitTestPiece(at: scenePoint) {
                sceneDelegate?.sceneDidLongPressPiece(pieceId)
            }
        case .ended, .cancelled, .failed:
            sceneDelegate?.sceneDidEndLongPress()
        default:
            break
        }
    }

    // MARK: - swipe (for double-direction pieces)

    private func attachSwipeRecognizers(to view: SKView) {
        let directions: [(UISwipeGestureRecognizer.Direction, Direction)] = [
            (.up, .up), (.down, .down), (.left, .left), (.right, .right)
        ]
        for (sysDir, gameDir) in directions {
            let sw = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            sw.direction = sysDir
            sw.delaysTouchesBegan = false
            sw.cancelsTouchesInView = false
            // We tag with the raw game-direction string so the handler can recover it.
            sw.name = gameDir.rawValue
            view.addGestureRecognizer(sw)
            swipeRecognizers.append(sw)
        }
    }

    @objc private func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
        guard let view = self.view,
              let dirName = recognizer.name,
              let gameDir = Direction(rawValue: dirName) else { return }
        let viewPoint = recognizer.location(in: view)
        let scenePoint = convertPoint(fromView: viewPoint)
        guard let pieceId = hitTestPiece(at: scenePoint) else { return }
        sceneDelegate?.sceneDidSwipePiece(pieceId, direction: gameDir)
    }
}

extension GameScene: UIGestureRecognizerDelegate {
    /// Pan and pinch cooperate (two-finger pan while zooming), and camera
    /// gestures don't suppress the swipe used by double-direction pieces.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        func isCameraGesture(_ g: UIGestureRecognizer) -> Bool {
            g === panGesture || g === pinchGesture
        }
        if isCameraGesture(gestureRecognizer) && isCameraGesture(other) { return true }
        if isCameraGesture(gestureRecognizer) && other is UISwipeGestureRecognizer { return true }
        return false
    }
}
