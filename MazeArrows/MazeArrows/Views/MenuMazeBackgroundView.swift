//
//  MenuMazeBackgroundView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  A lightweight, non-interactive SpriteKit vignette for the main menu.
//  It reuses the game's arrow renderer, but deliberately owns no gameplay
//  model, gestures, camera, audio, physics, or accessibility tree.
//

import SpriteKit
import SwiftUI

enum MenuMazePieceSelection: Hashable, Sendable {
    case front
    case back
    case alternatingEdges
    case stride(Int)
}

struct MenuMazeScenarioProfile: Hashable, Sendable {
    let maximumMoves: Int
    let initialMistakes: Int
    let mistakeMilestones: Set<Int>
    let hintCadence: Int?
    let selection: MenuMazePieceSelection
    let openingDelay: TimeInterval
    let regularFlyDelay: TimeInterval
    let hintFlyDelay: TimeInterval
    let betweenMoveDelay: TimeInterval
    let accelerationPerMove: TimeInterval
    let minimumDelay: TimeInterval

    func regularDelay(after moveCount: Int) -> TimeInterval {
        accelerated(regularFlyDelay, after: moveCount)
    }

    func continuationDelay(after moveCount: Int) -> TimeInterval {
        accelerated(betweenMoveDelay, after: moveCount)
    }

    private func accelerated(_ delay: TimeInterval, after moveCount: Int) -> TimeInterval {
        max(minimumDelay, delay - accelerationPerMove * Double(moveCount))
    }
}

enum MenuMazeScenario: Int, CaseIterable, Sendable {
    case carefulSolve
    case falseStart
    case guidedTrail
    case speedRun
    case comeback

    var next: Self {
        let nextIndex = (rawValue + 1) % Self.allCases.count
        return Self(rawValue: nextIndex) ?? .carefulSolve
    }

    var profile: MenuMazeScenarioProfile {
        switch self {
        case .carefulSolve:
            MenuMazeScenarioProfile(
                maximumMoves: 10,
                initialMistakes: 0,
                mistakeMilestones: [],
                hintCadence: 3,
                selection: .front,
                openingDelay: 1.00,
                regularFlyDelay: 0.28,
                hintFlyDelay: 0.64,
                betweenMoveDelay: 0.34,
                accelerationPerMove: 0,
                minimumDelay: 0.12
            )
        case .falseStart:
            MenuMazeScenarioProfile(
                maximumMoves: 12,
                initialMistakes: 2,
                mistakeMilestones: [3, 7],
                hintCadence: 5,
                selection: .alternatingEdges,
                openingDelay: 0.85,
                regularFlyDelay: 0.18,
                hintFlyDelay: 0.56,
                betweenMoveDelay: 0.24,
                accelerationPerMove: 0,
                minimumDelay: 0.10
            )
        case .guidedTrail:
            MenuMazeScenarioProfile(
                maximumMoves: 11,
                initialMistakes: 0,
                mistakeMilestones: [8],
                hintCadence: 1,
                selection: .back,
                openingDelay: 0.90,
                regularFlyDelay: 0.18,
                hintFlyDelay: 0.62,
                betweenMoveDelay: 0.18,
                accelerationPerMove: 0,
                minimumDelay: 0.10
            )
        case .speedRun:
            MenuMazeScenarioProfile(
                maximumMoves: 18,
                initialMistakes: 0,
                mistakeMilestones: [],
                hintCadence: nil,
                selection: .stride(5),
                openingDelay: 0.65,
                regularFlyDelay: 0.14,
                hintFlyDelay: 0.50,
                betweenMoveDelay: 0.14,
                accelerationPerMove: 0.006,
                minimumDelay: 0.06
            )
        case .comeback:
            MenuMazeScenarioProfile(
                maximumMoves: 14,
                initialMistakes: 1,
                mistakeMilestones: [1, 2, 6],
                hintCadence: 2,
                selection: .alternatingEdges,
                openingDelay: 0.80,
                regularFlyDelay: 0.18,
                hintFlyDelay: 0.54,
                betweenMoveDelay: 0.22,
                accelerationPerMove: 0.004,
                minimumDelay: 0.08
            )
        }
    }
}

struct MenuMazeBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let level: Level
    let theme: GameTheme
    let blurRadius: CGFloat
    let opacityScale: Double

    @State private var scene: MenuMazeScene
    @State private var isRevealed = false

    init(
        level: Level,
        theme: GameTheme,
        blurRadius: CGFloat = 3.5,
        opacityScale: Double = 1,
        onReady: @escaping @MainActor () -> Void = {}
    ) {
        self.level = level
        self.theme = theme
        self.blurRadius = blurRadius
        self.opacityScale = opacityScale
        _scene = State(initialValue: MenuMazeScene(
            level: level,
            theme: theme,
            onReady: onReady
        ))
    }

    var body: some View {
        SpriteView(
            scene: scene,
            isPaused: shouldPause,
            preferredFramesPerSecond: preferredFramesPerSecond,
            options: [.allowsTransparency, .shouldCullNonVisibleNodes, .ignoresSiblingOrder]
        )
        .blur(radius: blurRadius)
        .scaleEffect(1.035)
        // SKView paints one opaque frame before its first Metal draw. On a
        // dark theme that frame reads as a white flash through the menu
        // scrim, so the renderer stays fully transparent until it is past.
        .opacity(isRevealed ? contentOpacity : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.45)) {
                isRevealed = true
            }
        }
        .onChange(of: reduceMotion, initial: true) { _, enabled in
            scene.setReduceMotion(enabled)
        }
        .onChange(of: animationIsActive, initial: true) { _, isActive in
            scene.setAnimationActive(isActive)
        }
    }

    private var contentOpacity: Double {
        min(1, (theme.id == .neon ? 0.74 : 0.48) * opacityScale)
    }

    private var shouldPause: Bool {
        !animationIsActive
    }

    private var animationIsActive: Bool {
        scenePhase == .active
            && !reduceMotion
            && !debugAnimationDisabled
    }

    private var preferredFramesPerSecond: Int {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? 24 : 30
    }

    private var debugAnimationDisabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--debug-static-menu-background")
        #else
        false
        #endif
    }
}

@MainActor
private final class MenuMazeScene: SKScene {
    private static let initialFadeDuration: TimeInterval = 0.85
    private static let scenarioCrossfadeDuration: TimeInterval = 0.72

    private struct BoardPresentation {
        let board: Board
        let geometry: BoardGeometry
        let layer: SKNode
        let pieceNodes: [String: ArrowPieceNode]
    }

    private let level: Level
    private let theme: GameTheme
    private let scenarioClock = SKNode()
    private var contentLayer = SKNode()
    private var transitioningOutLayer: SKNode?

    private var board: Board
    private var geometry: BoardGeometry
    private var pieceNodes: [String: ArrowPieceNode] = [:]
    private var reduceMotion = false
    private var scenarioGeneration = 0
    private var activeScenario: MenuMazeScenario = .carefulSolve
    private var moveCount = 0
    private var remainingOpeningMistakes = 0
    private var mistakeMilestones: Set<Int> = []
    private var hasRendered = false
    private var animationIsActive = false
    private var didReportReady = false
    private let onReady: @MainActor () -> Void

    init(
        level: Level,
        theme: GameTheme,
        onReady: @escaping @MainActor () -> Void
    ) {
        self.level = level
        self.theme = theme
        self.onReady = onReady
        self.board = level.makeBoard()
        self.geometry = BoardGeometry(
            boardWidth: level.width,
            boardHeight: level.height,
            availableSize: CGSize(width: 390, height: 844),
            padding: 18
        )
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.ignoresSiblingOrder = true
        view.allowsTransparency = true

        if scenarioClock.parent == nil {
            addChild(scenarioClock)
        }

        hasRendered = true
        if reduceMotion || !animationIsActive {
            rebuildBoard()
        } else {
            beginScenarioCycle(rebuildsBoard: true, fadesIn: true)
        }

        if !didReportReady {
            didReportReady = true
            onReady()
        }
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        stopScenario()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard hasRendered,
              abs(size.width - oldSize.width) > 1 || abs(size.height - oldSize.height) > 1
        else { return }

        rebuildBoard()
        if !reduceMotion {
            beginScenarioCycle(rebuildsBoard: false, fadesIn: false)
        }
    }

    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled

        if enabled {
            stopScenario()
            if hasRendered { rebuildBoard() }
        } else if view != nil, animationIsActive {
            beginScenarioCycle(rebuildsBoard: true, fadesIn: true)
        }
    }

    func setAnimationActive(_ enabled: Bool) {
        guard animationIsActive != enabled else { return }
        animationIsActive = enabled
        guard hasRendered else { return }

        if enabled, !reduceMotion {
            beginScenarioCycle(rebuildsBoard: true, fadesIn: true)
        } else {
            stopScenario()
        }
    }

    private var baseContentAlpha: CGFloat {
        theme.id == .neon ? 0.90 : 0.78
    }

    private func beginScenarioCycle(
        rebuildsBoard: Bool = true,
        fadesIn: Bool = false
    ) {
        guard view != nil, animationIsActive, !reduceMotion else { return }

        scenarioGeneration += 1
        scenarioClock.removeAllActions()
        contentLayer.removeAllActions()
        pieceNodes.values.forEach {
            $0.interruptActions(completingPendingOperations: false)
        }

        moveCount = 0
        remainingOpeningMistakes = activeScenario.profile.initialMistakes
        mistakeMilestones.removeAll(keepingCapacity: true)
        if rebuildsBoard {
            rebuildBoard()
        }

        if fadesIn {
            contentLayer.alpha = 0
            let fade = SKAction.fadeAlpha(
                to: baseContentAlpha,
                duration: Self.initialFadeDuration
            )
            fade.timingMode = .easeInEaseOut
            contentLayer.run(fade, withKey: "menu-initial-fade")
        } else {
            contentLayer.alpha = baseContentAlpha
        }

        let fadeAllowance = fadesIn ? Self.initialFadeDuration * 0.45 : 0
        schedule(after: activeScenario.profile.openingDelay + fadeAllowance) { scene in
            scene.runScenarioOpening()
        }
    }

    private func stopScenario() {
        scenarioGeneration += 1
        scenarioClock.removeAllActions()
        contentLayer.removeAllActions()
        transitioningOutLayer?.removeAllActions()
        pieceNodes.values.forEach {
            $0.interruptActions(completingPendingOperations: false)
        }
    }

    private func runScenarioOpening() {
        guard remainingOpeningMistakes > 0 else {
            solveNextMove()
            return
        }

        remainingOpeningMistakes -= 1
        showIntentionalMistake { scene in
            scene.runScenarioOpening()
        }
    }

    private func showIntentionalMistake(
        then continuation: @escaping @MainActor (MenuMazeScene) -> Void
    ) {
        guard let piece = board.pieces.first(where: {
            pieceNodes[$0.id] != nil && !MoveValidator.canFlyOut(piece: $0, board: board)
        }), let node = pieceNodes[piece.id] else {
            continuation(self)
            return
        }

        node.runBlockedFeedback { [weak self] in
            self?.schedule(after: 0.28, operation: continuation)
        }
    }

    private func solveNextMove() {
        let profile = activeScenario.profile
        guard moveCount < profile.maximumMoves,
              !board.pieces.isEmpty
        else {
            finishScenarioCycle()
            return
        }

        if profile.mistakeMilestones.contains(moveCount),
           mistakeMilestones.insert(moveCount).inserted {
            showIntentionalMistake { $0.solveNextMove() }
            return
        }

        let available = board.pieces.filter {
            pieceNodes[$0.id] != nil && MoveValidator.canFlyOut(piece: $0, board: board)
        }
        guard !available.isEmpty else {
            finishScenarioCycle()
            return
        }

        let piece = selectedPiece(from: available, using: profile.selection)
        guard let node = pieceNodes[piece.id] else {
            finishScenarioCycle()
            return
        }

        if shouldShowHint(cadence: profile.hintCadence) {
            node.runHintFeedback()
            schedule(after: profile.hintFlyDelay) { $0.flyOutPiece(id: piece.id) }
        } else {
            schedule(after: profile.regularDelay(after: moveCount)) {
                $0.flyOutPiece(id: piece.id)
            }
        }
    }

    private func selectedPiece(
        from available: [ArrowPiece],
        using selection: MenuMazePieceSelection
    ) -> ArrowPiece {
        switch selection {
        case .front:
            return available[moveCount % available.count]
        case .back:
            return available[available.count - 1 - (moveCount % available.count)]
        case .alternatingEdges:
            return moveCount.isMultiple(of: 2) ? available[0] : available[available.count - 1]
        case .stride(let step):
            return available[(moveCount * max(1, step)) % available.count]
        }
    }

    private func shouldShowHint(cadence: Int?) -> Bool {
        guard let cadence, cadence > 0 else { return false }
        return moveCount.isMultiple(of: cadence)
    }

    private func flyOutPiece(id: String) {
        guard let piece = board.pieces.first(where: { $0.id == id }),
              MoveValidator.canFlyOut(piece: piece, board: board),
              let node = pieceNodes[id]
        else {
            schedule(after: 0.12) { $0.solveNextMove() }
            return
        }

        let distance = max(2, MoveValidator.exitDistanceInCells(for: piece, board: board))
        node.runFlyOut(distanceCells: distance) { [weak self, weak node] in
            guard let self else { return }
            self.board.removePiece(id: id)
            self.pieceNodes[id] = nil
            node?.removeFromParent()
            self.moveCount += 1
            let delay = self.activeScenario.profile.continuationDelay(after: self.moveCount)
            self.schedule(after: delay) { $0.solveNextMove() }
        }
    }

    private func finishScenarioCycle() {
        schedule(after: 0.85) { scene in
            scene.crossfadeToNextScenario()
        }
    }

    private func crossfadeToNextScenario() {
        guard view != nil, animationIsActive, !reduceMotion else { return }

        scenarioGeneration += 1
        scenarioClock.removeAllActions()
        contentLayer.removeAllActions()
        pieceNodes.values.forEach {
            $0.interruptActions(completingPendingOperations: false)
        }

        let outgoingLayer = contentLayer
        let incoming = makeBoardPresentation()
        incoming.layer.alpha = 0
        incoming.layer.zPosition = 1
        addChild(incoming.layer)

        transitioningOutLayer?.removeFromParent()
        transitioningOutLayer = outgoingLayer
        contentLayer = incoming.layer
        board = incoming.board
        geometry = incoming.geometry
        pieceNodes = incoming.pieceNodes
        activeScenario = activeScenario.next

        let fadeOut = SKAction.fadeOut(withDuration: Self.scenarioCrossfadeDuration)
        fadeOut.timingMode = .easeInEaseOut
        outgoingLayer.run(.sequence([fadeOut, .removeFromParent()]))

        let fadeIn = SKAction.fadeAlpha(
            to: baseContentAlpha,
            duration: Self.scenarioCrossfadeDuration
        )
        fadeIn.timingMode = .easeInEaseOut
        incoming.layer.run(fadeIn, withKey: "menu-scenario-fade-in")

        schedule(after: Self.scenarioCrossfadeDuration) { scene in
            scene.transitioningOutLayer = nil
            scene.contentLayer.zPosition = 0
            scene.beginScenarioCycle(rebuildsBoard: false, fadesIn: false)
        }
    }

    private func schedule(
        after delay: TimeInterval,
        operation: @escaping @MainActor (MenuMazeScene) -> Void
    ) {
        let generation = scenarioGeneration
        let action = SKAction.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self, self.scenarioGeneration == generation else { return }
                operation(self)
            }
        ])
        scenarioClock.run(action)
    }

    private func rebuildBoard() {
        pieceNodes.values.forEach {
            $0.interruptActions(completingPendingOperations: false)
        }
        transitioningOutLayer?.removeAllActions()
        transitioningOutLayer?.removeFromParent()
        transitioningOutLayer = nil
        contentLayer.removeAllActions()
        contentLayer.removeFromParent()

        let presentation = makeBoardPresentation()
        board = presentation.board
        geometry = presentation.geometry
        contentLayer = presentation.layer
        pieceNodes = presentation.pieceNodes
        contentLayer.zPosition = 0
        contentLayer.alpha = baseContentAlpha
        addChild(contentLayer)
    }

    private func makeBoardPresentation() -> BoardPresentation {
        let newBoard = level.makeBoard()
        let layout = adaptiveBackdropLayout(for: newBoard)
        let newGeometry = BoardGeometry(
            boardWidth: newBoard.width,
            boardHeight: newBoard.height,
            availableSize: layout.canvasSize,
            padding: max(16, min(layout.canvasSize.width, layout.canvasSize.height) * 0.025)
        )
        let layer = SKNode()
        layer.position = layout.offset
        layer.alpha = baseContentAlpha

        drawBoardBackground(in: layer, board: newBoard, geometry: newGeometry)
        var newPieceNodes: [String: ArrowPieceNode] = [:]
        newPieceNodes.reserveCapacity(newBoard.pieces.count)
        for piece in newBoard.pieces {
            let node = ArrowPieceNode(
                piece: piece,
                geometry: newGeometry,
                lineColor: theme.pieceStroke.uiColor,
                piecePalette: level.piecePalette,
                highlightColor: theme.danger.uiColor,
                hintColor: theme.success.uiColor,
                useGlow: false,
                showsOutline: false,
                reduceMotion: reduceMotion
            )
            node.zPosition = 10
            layer.addChild(node)
            newPieceNodes[piece.id] = node
        }

        return BoardPresentation(
            board: newBoard,
            geometry: newGeometry,
            layer: layer,
            pieceNodes: newPieceNodes
        )
    }

    /// Keeps the maze dense on iPad while limiting horizontal cropping on
    /// narrow iPhones. A strict aspect-fill makes this portrait board almost
    /// twice as wide as an iPhone screen and can leave an empty center strip.
    private func adaptiveBackdropLayout(
        for board: Board
    ) -> (canvasSize: CGSize, offset: CGPoint) {
        let safeWidth = max(1, size.width)
        let safeHeight = max(1, size.height)
        let boardAspect = CGFloat(board.width) / CGFloat(board.height)
        let sceneAspect = safeWidth / safeHeight

        let fittedWidth: CGFloat
        let fittedHeight: CGFloat
        if sceneAspect < boardAspect {
            fittedWidth = safeWidth
            fittedHeight = safeWidth / boardAspect
        } else {
            fittedHeight = safeHeight
            fittedWidth = safeHeight * boardAspect
        }

        let overscan: CGFloat = sceneAspect < 0.60 ? 1.28 : 1.06
        let canvasWidth = fittedWidth * overscan
        let canvasHeight = fittedHeight * overscan
        return (
            CGSize(width: canvasWidth, height: canvasHeight),
            CGPoint(
                x: (safeWidth - canvasWidth) / 2,
                y: (safeHeight - canvasHeight) / 2
            )
        )
    }

    private func drawBoardBackground(
        in layer: SKNode,
        board: Board,
        geometry: BoardGeometry
    ) {
        let boardSize = geometry.boardSize()
        let center = CGPoint(
            x: geometry.origin.x + boardSize.width / 2,
            y: geometry.origin.y + boardSize.height / 2
        )
        let cornerRadius = min(32, max(14, geometry.cellSize * 0.9))

        let background = SKShapeNode(rectOf: boardSize, cornerRadius: cornerRadius)
        background.position = center
        background.fillColor = theme.boardBackground.uiColor
        background.strokeColor = theme.glassBorder.uiColor
        background.lineWidth = 1.2
        background.alpha = theme.id == .neon ? 0.44 : 0.34
        background.zPosition = 0
        layer.addChild(background)

        let dotsPath = CGMutablePath()
        let dotRadius = max(0.45, min(1.0, geometry.cellSize * 0.04))
        for x in 0..<board.width {
            for y in 0..<board.height {
                let center = geometry.point(for: GridPoint(x: x, y: y))
                dotsPath.addEllipse(in: CGRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                ))
            }
        }

        let grid = SKShapeNode(path: dotsPath)
        grid.fillColor = theme.boardGrid.uiColor
        grid.strokeColor = .clear
        grid.alpha = 0.82
        grid.zPosition = 1
        layer.addChild(grid)
    }
}
