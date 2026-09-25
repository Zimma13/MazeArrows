//
//  OnboardingTutorialView.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Observation
import SwiftUI
import UIKit

private enum TutorialPrompt: Equatable {
    case tapArrow
    case pathBlocked
    case freePathFirst
    case hint
    case combo
    case lives
    case success

    var text: String {
        switch self {
        case .tapArrow: return OnboardingCopy.tapArrow
        case .pathBlocked: return OnboardingCopy.pathBlocked
        case .freePathFirst: return OnboardingCopy.freePathFirst
        case .hint: return OnboardingCopy.hintShowsMove
        case .combo: return OnboardingCopy.combo
        case .lives: return OnboardingCopy.livesRule
        case .success: return OnboardingCopy.great
        }
    }
}

@MainActor
@Observable
private final class TutorialGameModel {
    enum ScriptPhase {
        case playing
        case awaitingBlockedDemo
        case awaitingBlocker
        case celebrating
    }

    let definition: TutorialLevelDefinition
    var board: Board
    var prompt: TutorialPrompt
    var spotlightID: String?
    var showHand: Bool
    var showHintPulse = false
    var hintsAreVisible = false
    var comboCount = 0
    var lives: Int?
    var exitingPieceID: String?
    var exitingDirection: Direction = .right
    var exitDuration = 0.28
    var shakenPieceID: String?
    var shakeTrigger = 0
    var isInputLocked = false
    var isFinished = false

    @ObservationIgnored
    private var transitionTask: Task<Void, Never>?

    private var phase: ScriptPhase
    private var comboIndex = 0
    private var hasRunFirstExit = false

    init(definition: TutorialLevelDefinition) {
        self.definition = definition
        self.board = definition.board
        self.spotlightID = definition.initialSpotlightID
        self.showHand = definition.initialSpotlightID != nil
        self.lives = definition.startingLives

        switch definition.stage {
        case .one:
            self.prompt = .tapArrow
            self.phase = .playing
        case .two:
            self.prompt = .tapArrow
            self.phase = .awaitingBlockedDemo
        case .three:
            self.prompt = .hint
            self.phase = .playing
        case .four:
            self.prompt = .lives
            self.phase = .awaitingBlockedDemo
        }
    }

    deinit {
        transitionTask?.cancel()
    }

    func start() {
        // The action cue is part of the initial lesson state, not an idle hint.
        // Show it as soon as the board is laid out so the player never waits to
        // discover which arrow to tap.
        if definition.initialSpotlightID != nil {
            showHand = true
        }
        if definition.stage == .three {
            showFreeHint()
        }
    }

    func stop() {
        transitionTask?.cancel()
        transitionTask = nil
    }

    func tapPiece(
        id: String,
        reduceMotion: Bool,
        hapticsEnabled: Bool
    ) {
        guard !isInputLocked,
              phase != .celebrating,
              let piece = board.pieces.first(where: { $0.id == id })
        else { return }

        // Dimmed pieces provide board context, but are not part of the
        // current lesson action. Keep the scripted path deterministic even
        // if an event is delivered outside the disabled button state.
        guard spotlightID == nil || spotlightID == id else { return }

        showHand = false

        if phase == .awaitingBlockedDemo,
           id == definition.forcedBlockedPieceID {
            runBlockedDemo(piece: piece, reduceMotion: reduceMotion, hapticsEnabled: hapticsEnabled)
            return
        }

        if phase == .awaitingBlockedDemo {
            shake(
                pieceID: definition.forcedBlockedPieceID ?? id,
                reduceMotion: reduceMotion,
                hapticsEnabled: hapticsEnabled
            )
            return
        }

        if phase == .awaitingBlocker,
           id != definition.forcedBlockerPieceID {
            shake(pieceID: id, reduceMotion: reduceMotion, hapticsEnabled: hapticsEnabled)
            return
        }

        guard MoveValidator.canFlyOut(piece: piece, board: board) else {
            if definition.stage == .three {
                showFreeHint()
            }
            if definition.stage == .four {
                lives = max(1, (lives ?? 3) - 1)
            }
            shake(pieceID: id, reduceMotion: reduceMotion, hapticsEnabled: hapticsEnabled)
            return
        }

        flyOut(piece, reduceMotion: reduceMotion, hapticsEnabled: hapticsEnabled)
    }

    private func runBlockedDemo(
        piece: ArrowPiece,
        reduceMotion: Bool,
        hapticsEnabled: Bool
    ) {
        if definition.stage == .four {
            lives = max(1, (lives ?? 3) - 1)
            prompt = .lives
        } else {
            prompt = .pathBlocked
        }
        shake(pieceID: piece.id, reduceMotion: reduceMotion, hapticsEnabled: hapticsEnabled)
        isInputLocked = true

        transitionTask?.cancel()
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: reduceMotion ? .milliseconds(120) : .milliseconds(620))
            guard let self, !Task.isCancelled else { return }
            self.phase = .awaitingBlocker
            self.prompt = .freePathFirst
            self.spotlightID = self.definition.forcedBlockerPieceID
            self.isInputLocked = false
            self.showHand = true
        }
    }

    private func flyOut(
        _ piece: ArrowPiece,
        reduceMotion: Bool,
        hapticsEnabled: Bool
    ) {
        isInputLocked = true
        exitingPieceID = piece.id
        exitingDirection = piece.direction
        exitDuration = reduceMotion ? 0.01 : (!hasRunFirstExit && definition.stage == .one ? 0.5 : 0.28)
        hasRunFirstExit = true
        impact(.light, enabled: hapticsEnabled)

        transitionTask?.cancel()
        transitionTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.exitDuration))
            guard !Task.isCancelled else { return }
            self.board.removePiece(id: piece.id)
            self.exitingPieceID = nil
            self.isInputLocked = false
            self.handleRemoval(of: piece.id, reduceMotion: reduceMotion, hapticsEnabled: hapticsEnabled)
        }
    }

    private func handleRemoval(
        of pieceID: String,
        reduceMotion: Bool,
        hapticsEnabled: Bool
    ) {
        if phase == .awaitingBlocker,
           pieceID == definition.forcedBlockerPieceID {
            phase = .playing
            spotlightID = definition.forcedBlockedPieceID
            prompt = definition.stage == .four ? .lives : .freePathFirst
            showHand = true
        }

        if definition.stage == .three,
           comboIndex < definition.comboSequence.count,
           pieceID == definition.comboSequence[comboIndex] {
            comboIndex += 1
            comboCount = comboIndex
            impact(comboIndex == 3 ? .heavy : .medium, enabled: hapticsEnabled)

            if comboIndex < definition.comboSequence.count {
                spotlightID = definition.comboSequence[comboIndex]
                showHintPulse = true
            } else {
                prompt = .combo
                showHintPulse = false
                finishCombo(reduceMotion: reduceMotion)
                return
            }
        }

        if completesLesson(afterRemoving: pieceID) {
            celebrate(reduceMotion: reduceMotion)
            return
        }

        if board.pieces.isEmpty {
            celebrate(reduceMotion: reduceMotion)
        }
    }

    private func completesLesson(afterRemoving pieceID: String) -> Bool {
        switch definition.stage {
        case .one:
            return definition.initialSpotlightID == pieceID
        case .two, .four:
            return definition.forcedBlockedPieceID == pieceID
        case .three:
            // Stage three has an ordered combo and finishes in `finishCombo`.
            return false
        }
    }

    private func finishCombo(reduceMotion: Bool) {
        isInputLocked = true
        phase = .celebrating
        transitionTask?.cancel()
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: reduceMotion ? .milliseconds(180) : .milliseconds(650))
            guard let self, !Task.isCancelled else { return }
            self.board.replaceAll(with: [])
            self.isFinished = true
        }
    }

    private func celebrate(reduceMotion: Bool) {
        phase = .celebrating
        prompt = definition.stage == .three ? .combo : .success
        // Keep the removed final piece as the spotlight target until the
        // screen leaves. Since it is no longer on the board, every remaining
        // context piece stays dim instead of briefly flashing to full opacity.
        isInputLocked = true
        transitionTask?.cancel()
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: reduceMotion ? .milliseconds(180) : .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.isFinished = true
        }
    }

    private func showFreeHint() {
        guard definition.stage == .three, comboIndex == 0, phase != .celebrating else { return }
        hintsAreVisible = true
        showHintPulse = true
        spotlightID = "C"
        prompt = .hint
        showHand = true
    }

    private func shake(pieceID: String, reduceMotion: Bool, hapticsEnabled: Bool) {
        shakenPieceID = pieceID
        shakeTrigger += 1
        impact(.rigid, enabled: hapticsEnabled)

        if reduceMotion {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled, self?.shakenPieceID == pieceID else { return }
                self?.shakenPieceID = nil
            }
        }
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, enabled: Bool) {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct OnboardingTutorialView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SettingsStore.self) private var settings

    @State private var model: TutorialGameModel

    private let onFinished: () -> Void

    init(stage: TutorialStage, onFinished: @escaping () -> Void) {
        _model = State(initialValue: TutorialGameModel(
            definition: TutorialLevelDefinition.definition(for: stage)
        ))
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            TutorialPlaque(
                text: model.prompt.text,
                tone: plaqueTone,
                theme: theme
            )
            .animation(.easeInOut(duration: 0.22), value: model.prompt)

            TutorialBoardView(
                board: model.board,
                theme: theme,
                spotlightID: model.spotlightID,
                showHand: model.showHand,
                showHintPulse: model.showHintPulse,
                exitingPieceID: model.exitingPieceID,
                exitingDirection: model.exitingDirection,
                exitDuration: model.exitDuration,
                shakenPieceID: model.shakenPieceID,
                shakeTrigger: model.shakeTrigger,
                reduceMotion: reduceMotion,
                isInputLocked: model.isInputLocked,
                onTapPiece: handleTap
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 410)

            TutorialHUD(
                stage: model.definition.stage,
                lives: model.lives,
                hintsAreVisible: model.hintsAreVisible,
                comboCount: model.comboCount,
                theme: theme
            )

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .task { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: model.isFinished) {
            if model.isFinished { onFinished() }
        }
    }

    private var theme: GameTheme {
        GameTheme.theme(for: settings.settings.themeID)
    }

    private var plaqueTone: TutorialPlaque.Tone {
        switch model.prompt {
        case .pathBlocked, .lives: return .danger
        case .success, .combo: return .success
        default: return .normal
        }
    }

    private func handleTap(_ id: String) {
        model.tapPiece(
            id: id,
            reduceMotion: reduceMotion,
            hapticsEnabled: settings.settings.hapticsEnabled
        )
    }
}

private struct TutorialPlaque: View {
    enum Tone {
        case normal
        case danger
        case success
    }

    let text: String
    let tone: Tone
    let theme: GameTheme

    var body: some View {
        Text(text)
            .scaledFont(size: 18, weight: .bold, design: .rounded, relativeTo: .headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: 420)
            .background(background, in: Capsule())
            .overlay {
                Capsule().strokeBorder(theme.glassBorder, lineWidth: 1)
            }
            .accessibilityAddTraits(.isHeader)
    }

    private var foreground: Color {
        switch tone {
        case .normal: return theme.ink
        case .danger: return theme.textOnDanger
        case .success: return theme.textOnSuccess
        }
    }

    private var background: Color {
        switch tone {
        case .normal: return theme.glassSolid
        case .danger: return theme.danger
        case .success: return theme.success
        }
    }
}

private struct TutorialHUD: View {
    let stage: TutorialStage
    let lives: Int?
    let hintsAreVisible: Bool
    let comboCount: Int
    let theme: GameTheme

    var body: some View {
        HStack(spacing: 14) {
            if let lives {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < lives ? "heart.fill" : "heart")
                            .foregroundStyle(index < lives ? theme.heartFill : theme.inkMuted)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(OnboardingCopy.livesCount(lives))
            }

            if hintsAreVisible {
                Label(OnboardingCopy.hintsThree, systemImage: "lightbulb.fill")
                    .foregroundStyle(theme.accent)
            }

            if comboCount > 1 {
                Text("×\(comboCount)")
                    .scaledFont(size: 20, weight: .bold, design: .rounded, relativeTo: .headline)
                    .foregroundStyle(theme.success)
                    .contentTransition(.numericText())
            }

            if lives == nil, !hintsAreVisible, comboCount <= 1 {
                Text(OnboardingCopy.levelNumber(stage.rawValue))
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .scaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
        .frame(minHeight: 44)
    }
}

private struct TutorialBoardView: View {
    let board: Board
    let theme: GameTheme
    let spotlightID: String?
    let showHand: Bool
    let showHintPulse: Bool
    let exitingPieceID: String?
    let exitingDirection: Direction
    let exitDuration: Double
    let shakenPieceID: String?
    let shakeTrigger: Int
    let reduceMotion: Bool
    let isInputLocked: Bool
    let onTapPiece: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(board.width)

            ZStack(alignment: .topLeading) {
                TutorialGrid(board: board, theme: theme)

                ForEach(board.pieces) { piece in
                    TutorialPieceButton(
                        piece: piece,
                        board: board,
                        cellSize: cell,
                        boardSide: side,
                        theme: theme,
                        isSpotlighted: spotlightID == nil || spotlightID == piece.id,
                        isExiting: exitingPieceID == piece.id,
                        exitingDirection: exitingDirection,
                        exitDuration: exitDuration,
                        shakeValue: shakenPieceID == piece.id ? CGFloat(shakeTrigger) : 0,
                        reduceMotion: reduceMotion,
                        isDisabled: isInputLocked || (spotlightID != nil && spotlightID != piece.id),
                        action: { onTapPiece(piece.id) }
                    )
                }

                if showHand, let spotlightID,
                   let piece = board.pieces.first(where: { $0.id == spotlightID }) {
                    let center = pieceCenter(piece, cellSize: cell)
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: max(28, cell * 0.72), weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(theme.surface, theme.accent)
                        .shadow(color: theme.ink.opacity(0.22), radius: 4, y: 3)
                        .position(x: center.x + cell * 0.46, y: center.y + cell * 0.54)
                        .scaleEffect(reduceMotion ? 1 : (showHintPulse ? 1.08 : 1))
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                            value: showHintPulse
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: side, height: side)
            .background(theme.boardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(theme.glassBorder, lineWidth: 1)
            }
            .shadow(color: theme.primaryShadow.opacity(0.14), radius: 20, y: 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func pieceCenter(_ piece: ArrowPiece, cellSize: CGFloat) -> CGPoint {
        let averageX = piece.cells.map { CGFloat($0.x) }.reduce(0, +) / CGFloat(piece.cells.count)
        let averageY = piece.cells.map { CGFloat($0.y) }.reduce(0, +) / CGFloat(piece.cells.count)
        return CGPoint(
            x: (averageX + 0.5) * cellSize,
            y: (averageY + 0.5) * cellSize
        )
    }
}

private struct TutorialGrid: View {
    let board: Board
    let theme: GameTheme

    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / CGFloat(board.width)
            let cellHeight = size.height / CGFloat(board.height)
            var path = Path()

            for column in 1..<board.width {
                let x = CGFloat(column) * cellWidth
                path.move(to: CGPoint(x: x, y: 18))
                path.addLine(to: CGPoint(x: x, y: size.height - 18))
            }
            for row in 1..<board.height {
                let y = CGFloat(row) * cellHeight
                path.move(to: CGPoint(x: 18, y: y))
                path.addLine(to: CGPoint(x: size.width - 18, y: y))
            }
            context.stroke(path, with: .color(theme.boardGrid), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 28))
        .accessibilityHidden(true)
    }
}

private struct TutorialPieceButton: View {
    let piece: ArrowPiece
    let board: Board
    let cellSize: CGFloat
    let boardSide: CGFloat
    let theme: GameTheme
    let isSpotlighted: Bool
    let isExiting: Bool
    let exitingDirection: Direction
    let exitDuration: Double
    let shakeValue: CGFloat
    let reduceMotion: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(piece.cells.enumerated()), id: \.offset) { _, point in
                    RoundedRectangle(cornerRadius: cellSize * 0.21, style: .continuous)
                        .fill(pieceColor)
                        .frame(width: cellSize * 0.86, height: cellSize * 0.86)
                        .offset(
                            x: CGFloat(point.x - minX) * cellSize + cellSize * 0.07,
                            y: CGFloat(point.y - minY) * cellSize + cellSize * 0.07
                        )
                }

                Image(systemName: piece.direction.systemImageName)
                    .font(.system(size: cellSize * 0.43, weight: .black))
                    .foregroundStyle(theme.boardBackground)
                    .frame(width: cellSize, height: cellSize)
                    .offset(
                        x: CGFloat(piece.headCell.x - minX) * cellSize,
                        y: CGFloat(piece.headCell.y - minY) * cellSize
                    )
            }
            .frame(width: pieceWidth, height: pieceHeight, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isSpotlighted ? 1 : 0.28)
        .scaleEffect(isSpotlighted ? 1 : 0.94)
        .shadow(
            color: isSpotlighted ? pieceColor.opacity(theme.pieceGlow ? 0.75 : 0.25) : .clear,
            radius: isSpotlighted ? 10 : 0
        )
        .position(
            x: (CGFloat(minX) + CGFloat(maxX - minX + 1) / 2) * cellSize,
            y: (CGFloat(minY) + CGFloat(maxY - minY + 1) / 2) * cellSize
        )
        .offset(exitOffset)
        .opacity(isExiting ? 0 : (isSpotlighted ? 1 : 0.28))
        .overlay {
            if reduceMotion, shakeValue > 0 {
                RoundedRectangle(cornerRadius: cellSize * 0.26, style: .continuous)
                    .strokeBorder(theme.danger, lineWidth: 3)
            }
        }
        .modifier(TutorialShakeModifier(shakes: reduceMotion ? 0 : shakeValue))
        .animation(.easeIn(duration: exitDuration), value: isExiting)
        .animation(.easeInOut(duration: 0.25), value: isSpotlighted)
        .animation(.linear(duration: reduceMotion ? 0.01 : 0.35), value: shakeValue)
        .accessibilityLabel(OnboardingCopy.arrowAccessibility(piece.id, piece.direction.localizedName))
        .accessibilityHint(
            MoveValidator.canFlyOut(piece: piece, board: board)
                ? OnboardingCopy.arrowFreeAccessibility
                : OnboardingCopy.arrowBlockedAccessibility
        )
    }

    private var minX: Int { piece.cells.map(\.x).min() ?? 0 }
    private var maxX: Int { piece.cells.map(\.x).max() ?? 0 }
    private var minY: Int { piece.cells.map(\.y).min() ?? 0 }
    private var maxY: Int { piece.cells.map(\.y).max() ?? 0 }
    private var pieceWidth: CGFloat { CGFloat(maxX - minX + 1) * cellSize }
    private var pieceHeight: CGFloat { CGFloat(maxY - minY + 1) * cellSize }

    private var pieceColor: Color {
        let palette = [
            theme.accent,
            theme.accent2,
            theme.success,
            theme.achievementGold,
            theme.danger,
            theme.pieceStroke
        ]
        return palette[(piece.colorGroup ?? 0) % palette.count]
    }

    private var exitOffset: CGSize {
        guard isExiting else { return .zero }
        let distance = boardSide * 1.15
        return CGSize(
            width: CGFloat(exitingDirection.dx) * distance,
            height: CGFloat(exitingDirection.dy) * distance
        )
    }
}

private struct TutorialShakeModifier: ViewModifier, Animatable {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(x: sin(shakes * .pi * 4) * 9)
    }
}

private extension Direction {
    var systemImageName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    var localizedName: String {
        switch self {
        case .up: return OnboardingCopy.directionUp
        case .down: return OnboardingCopy.directionDown
        case .left: return OnboardingCopy.directionLeft
        case .right: return OnboardingCopy.directionRight
        }
    }
}
