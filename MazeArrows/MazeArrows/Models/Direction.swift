//
//  Direction.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import CoreGraphics

nonisolated enum Direction: String, Codable, CaseIterable, Sendable {
    case up, down, left, right

    /// Grid-space deltas (y grows down).
    var dx: Int {
        switch self {
        case .left:  return -1
        case .right: return  1
        case .up, .down: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up:    return -1
        case .down:  return  1
        case .left, .right: return 0
        }
    }

    var vector: CGVector { CGVector(dx: CGFloat(dx), dy: CGFloat(dy)) }

    /// Visual unit vector in SpriteKit space (y up).
    var spriteVector: CGVector {
        switch self {
        case .right: return CGVector(dx:  1, dy:  0)
        case .left:  return CGVector(dx: -1, dy:  0)
        case .up:    return CGVector(dx:  0, dy:  1)
        case .down:  return CGVector(dx:  0, dy: -1)
        }
    }

    /// Rotation for an arrow-head built pointing to +x, applied in SpriteKit.
    var spriteAngle: CGFloat {
        switch self {
        case .right: return  0
        case .up:    return  .pi / 2
        case .left:  return  .pi
        case .down:  return -.pi / 2
        }
    }

    var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    var isHorizontal: Bool { self == .left || self == .right }
}
