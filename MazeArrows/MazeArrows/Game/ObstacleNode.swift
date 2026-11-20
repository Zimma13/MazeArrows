//
//  ObstacleNode.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  SpriteKit rendering for field obstacles (walls, gates, portals, ice,
//  springs, destructibles). Each obstacle is one node sized to a cell.
//

import SpriteKit
import UIKit

final class ObstacleNode: SKNode {
    let obstacle: Obstacle
    private let geometry: BoardGeometry
    private let theme: GameTheme
    private var reduceMotion: Bool
    private var destroyCompletion: (() -> Void)?
    private(set) var isBeingDestroyed = false
    private(set) var isKeyGateOpen: Bool
    private var gateBars: SKNode?
    private var gateSymbol: SKShapeNode?
    private var gateHighlight: SKShapeNode?

    init(
        obstacle: Obstacle,
        geometry: BoardGeometry,
        theme: GameTheme,
        reduceMotion: Bool = false,
        isKeyGateOpen: Bool = false
    ) {
        self.obstacle = obstacle
        self.geometry = geometry
        self.theme = theme
        self.reduceMotion = reduceMotion
        self.isKeyGateOpen = isKeyGateOpen
        super.init()
        self.position = geometry.point(for: obstacle.cell)
        self.name = "obstacle_\(obstacle.id)"
        build()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func build() {
        let size = geometry.cellSize * 0.88
        switch obstacle.kind {
        case .wall:
            addWall(size: size)
        case .gate:
            addGate(size: size)
        case .keyGate:
            addKeyGate(size: size)
        case .portal:
            addPortal(size: size)
        case .ice:
            addIce(size: size)
        case .spring:
            addSpring(size: size)
        case .destructible:
            addDestructible(size: size)
        }
    }

    private func addWall(size: CGFloat) {
        let rect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        let shape = SKShapeNode(rect: rect, cornerRadius: size * 0.08)
        shape.fillColor = theme.inkSoft.uiColor
        shape.strokeColor = theme.ink.uiColor.withAlphaComponent(0.6)
        shape.lineWidth = 2
        shape.zPosition = 5
        addChild(shape)
        // brick hatching
        let hatch1 = SKShapeNode(rect: CGRect(x: -size/2, y: 0, width: size, height: 1))
        hatch1.fillColor = .black.withAlphaComponent(0.18)
        hatch1.strokeColor = .clear
        hatch1.zPosition = 6
        addChild(hatch1)
        let hatch2 = SKShapeNode(rect: CGRect(x: 0, y: -size/2, width: 1, height: size))
        hatch2.fillColor = .black.withAlphaComponent(0.18)
        hatch2.strokeColor = .clear
        hatch2.zPosition = 6
        addChild(hatch2)
    }

    private func addGate(size: CGFloat) {
        let shape = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.18)
        shape.fillColor = theme.accent.uiColor.withAlphaComponent(0.25)
        shape.strokeColor = theme.accent.uiColor
        shape.lineWidth = 2.5
        shape.zPosition = 5
        addChild(shape)
        // Arrow inside indicating allowed direction.
        if let dir = obstacle.gateDirection {
            let arrow = SKLabelNode(text: arrowGlyph(for: dir))
            arrow.fontName = "AvenirNext-Heavy"
            arrow.fontSize = size * 0.55
            arrow.fontColor = theme.accent.uiColor
            arrow.horizontalAlignmentMode = .center
            arrow.verticalAlignmentMode = .center
            arrow.zPosition = 6
            addChild(arrow)
        }
        if let group = obstacle.colorGroup {
            let marker = SKLabelNode(text: "\(group)")
            marker.fontName = "AvenirNext-Heavy"
            marker.fontSize = max(7, size * 0.22)
            marker.fontColor = theme.ink.uiColor
            marker.horizontalAlignmentMode = .center
            marker.verticalAlignmentMode = .center
            marker.position = CGPoint(x: size * 0.30, y: -size * 0.30)
            marker.zPosition = 7
            addChild(marker)
        }
    }

    /// A gate has four corner posts and a removable barrier. Open gates leave
    /// a clear centre in both axes, including the shared-crossing levels.
    /// This deliberately has no direction arrow, unlike the legacy filter.
    private func addKeyGate(size: CGFloat) {
        let color = obstacle.colorGroup == 2 ? theme.accent2.uiColor : theme.accent.uiColor
        let half = size * 0.43
        let inner = size * 0.27
        let postsPath = CGMutablePath()
        for x: CGFloat in [-1, 1] {
            for y: CGFloat in [-1, 1] {
                postsPath.move(to: CGPoint(x: x * inner, y: y * half))
                postsPath.addLine(to: CGPoint(x: x * half, y: y * half))
                postsPath.addLine(to: CGPoint(x: x * half, y: y * inner))
            }
        }
        let posts = SKShapeNode(path: postsPath)
        posts.name = "key-gate-frame"
        posts.strokeColor = color
        posts.lineWidth = max(2, size * 0.075)
        posts.lineCap = .round
        posts.lineJoin = .round
        posts.zPosition = 5
        addChild(posts)

        let bars = SKNode()
        bars.name = "key-gate-barrier"
        // A broad, solid rail reads as a closed passage at normal board
        // scale. Keep the symbol above it instead of covering the barrier.
        let barrier = SKShapeNode(
            rectOf: CGSize(width: size * 0.82, height: size * 0.18),
            cornerRadius: size * 0.055
        )
        barrier.fillColor = color
        barrier.strokeColor = .clear
        barrier.position.y = -size * 0.11
        bars.addChild(barrier)
        bars.zPosition = 6
        addChild(bars)
        gateBars = bars

        let symbol = SKShapeNode()
        symbol.name = "key-gate-symbol"
        symbol.strokeColor = theme.ink.uiColor
        symbol.fillColor = theme.boardBackground.uiColor
        symbol.lineWidth = max(2, size * 0.07)
        symbol.lineJoin = .round
        symbol.zPosition = 8
        addChild(symbol)
        gateSymbol = symbol

        let highlight = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.20)
        highlight.name = "key-gate-connection"
        highlight.strokeColor = .clear
        highlight.fillColor = color.withAlphaComponent(0.22)
        highlight.lineWidth = 0
        highlight.zPosition = 4
        highlight.isHidden = true
        addChild(highlight)
        gateHighlight = highlight
        applyKeyGateState()
    }

    /// The open state is derived from Board, never stored as an animation
    /// side effect. Updating every gate synchronously keeps a group atomic.
    func setKeyGateOpen(_ open: Bool, animated: Bool = false) {
        guard obstacle.kind == .keyGate else { return }
        let changed = isKeyGateOpen != open
        isKeyGateOpen = open
        applyKeyGateState()
        guard changed, open, animated, !reduceMotion else { return }

        // Only the frame glints. The final passable centre is already clear,
        // so a subsequent move never sees a visually half-open barrier.
        guard let frame = childNode(withName: "key-gate-frame") else { return }
        frame.run(.sequence([
            .fadeAlpha(to: 0.45, duration: 0.08),
            .fadeAlpha(to: 1, duration: 0.12)
        ]), withKey: "key-gate-open")
    }

    private func applyKeyGateState() {
        let size = geometry.cellSize * 0.88
        childNode(withName: "key-gate-frame")?.removeAction(forKey: "key-gate-open")
        childNode(withName: "key-gate-frame")?.alpha = 1
        gateBars?.isHidden = isKeyGateOpen
        gateSymbol?.path = KeyGateSymbol.path(
            group: obstacle.colorGroup ?? 1,
            radius: size * (isKeyGateOpen ? 0.115 : 0.16)
        )
        gateSymbol?.position = isKeyGateOpen
            ? CGPoint(x: size * 0.31, y: size * 0.31)
            : CGPoint(x: 0, y: size * 0.23)
    }

    func setConnectionHighlighted(_ highlighted: Bool) {
        gateHighlight?.isHidden = !highlighted
    }

    private func addPortal(size: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: size * 0.45)
        ring.fillColor = theme.accent2.uiColor.withAlphaComponent(0.3)
        ring.strokeColor = theme.accent2.uiColor
        ring.lineWidth = 3
        ring.zPosition = 5
        ring.name = "portal-ring"
        addChild(ring)
        let inner = SKShapeNode(circleOfRadius: size * 0.20)
        inner.fillColor = theme.accent2.uiColor
        inner.strokeColor = .clear
        inner.zPosition = 6
        addChild(inner)
        // Subtle slow pulse to feel "active".
        updatePortalMotion()
    }

    private func addIce(size: CGFloat) {
        let shape = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.18)
        shape.fillColor = UIColor(red: 0.78, green: 0.92, blue: 1.0, alpha: 0.5)
        shape.strokeColor = UIColor(red: 0.5, green: 0.75, blue: 1.0, alpha: 0.9)
        shape.lineWidth = 1.5
        shape.zPosition = 5
        addChild(shape)
        let snow = SKLabelNode(text: "❄")
        snow.fontSize = size * 0.55
        snow.fontColor = UIColor(red: 0.3, green: 0.55, blue: 0.9, alpha: 0.85)
        snow.horizontalAlignmentMode = .center
        snow.verticalAlignmentMode = .center
        snow.zPosition = 6
        addChild(snow)
    }

    private func addSpring(size: CGFloat) {
        let shape = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.20)
        shape.fillColor = theme.success.uiColor.withAlphaComponent(0.30)
        shape.strokeColor = theme.success.uiColor
        shape.lineWidth = 2.5
        shape.zPosition = 5
        addChild(shape)
        let label = SKLabelNode(text: "↯")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = size * 0.6
        label.fontColor = theme.success.uiColor
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 6
        addChild(label)
    }

    private func addDestructible(size: CGFloat) {
        let shape = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.10)
        shape.fillColor = theme.danger.uiColor.withAlphaComponent(0.25)
        shape.strokeColor = theme.danger.uiColor
        shape.lineWidth = 2
        shape.zPosition = 5
        addChild(shape)
        // A faint X to show it's breakable.
        let x = SKLabelNode(text: "✕")
        x.fontName = "AvenirNext-Heavy"
        x.fontSize = size * 0.55
        x.fontColor = theme.danger.uiColor
        x.horizontalAlignmentMode = .center
        x.verticalAlignmentMode = .center
        x.zPosition = 6
        addChild(x)
    }

    private func arrowGlyph(for direction: Direction) -> String {
        switch direction {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        }
    }

    /// Play a small explode-and-vanish for destructibles.
    func runDestroy(onComplete: @escaping () -> Void) {
        finishDestroy()
        destroyCompletion = onComplete
        isBeingDestroyed = true
        let remove = SKAction.run { [weak self] in
            self?.removeFromParent()
            self?.finishDestroy()
        }
        if reduceMotion {
            run(.sequence([.fadeOut(withDuration: 0.12), remove]), withKey: "destroy")
        } else {
            let scaleUp = SKAction.scale(to: 1.25, duration: 0.08)
            let fadeOut = SKAction.group([
                .scale(to: 0.6, duration: 0.18),
                .fadeOut(withDuration: 0.18)
            ])
            run(.sequence([scaleUp, fadeOut, remove]), withKey: "destroy")
        }
    }

    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled
        if enabled, obstacle.kind == .keyGate {
            applyKeyGateState()
        }
        updatePortalMotion()
    }

    private func updatePortalMotion() {
        guard obstacle.kind == .portal,
              let ring = childNode(withName: "portal-ring")
        else { return }

        ring.removeAction(forKey: "portal-pulse")
        ring.setScale(1)
        guard !reduceMotion else { return }

        let pulse = SKAction.sequence([
            .scale(to: 1.10, duration: 0.7),
            .scale(to: 1.00, duration: 0.7)
        ])
        ring.run(.repeatForever(pulse), withKey: "portal-pulse")
    }

    func interruptActions(completingPendingOperation: Bool) {
        removeActionsRecursively(from: self)
        let completion = destroyCompletion
        destroyCompletion = nil
        isBeingDestroyed = false
        if completingPendingOperation {
            removeFromParent()
            completion?()
        }
    }

    private func finishDestroy() {
        let completion = destroyCompletion
        destroyCompletion = nil
        isBeingDestroyed = false
        completion?()
    }

    private func removeActionsRecursively(from node: SKNode) {
        node.removeAllActions()
        for child in node.children {
            removeActionsRecursively(from: child)
        }
    }
}

/// Use the same geometric marks on linked keys and gates. Font glyphs have
/// very thin strokes at cell size, even when rendered with a heavy font.
enum KeyGateSymbol {
    static func path(group: Int, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        if group == 2 {
            path.move(to: CGPoint(x: 0, y: radius))
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -radius))
            path.addLine(to: CGPoint(x: -radius, y: 0))
            path.closeSubpath()
        } else {
            path.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}
