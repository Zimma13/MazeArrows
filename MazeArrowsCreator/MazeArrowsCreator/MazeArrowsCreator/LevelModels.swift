import SwiftUI

// MARK: - Grid primitives

nonisolated struct GridCell: Hashable, Equatable, Sendable {
    var x: Int
    var y: Int
}

nonisolated enum Direction: String, CaseIterable, Sendable {
    case up, down, left, right

    var delta: (dx: Int, dy: Int) {
        switch self {
        case .up:    return (0, -1)
        case .down:  return (0, 1)
        case .left:  return (-1, 0)
        case .right: return (1, 0)
        }
    }

    var arrow: String {
        switch self { case .up: "▲"; case .down: "▼"; case .left: "◀"; case .right: "▶" }
    }

    static func from(dx: Int, dy: Int) -> Direction? {
        allCases.first { $0.delta.dx == dx && $0.delta.dy == dy }
    }
}

// MARK: - Piece kinds

nonisolated enum PieceKind: String, CaseIterable, Sendable {
    case standard, heavy, fragile, frozen, double, lockedLock, lockedKey, bomb, chain

    var displayName: String {
        switch self {
        case .standard:   "Обычная"
        case .heavy:      "Тяжёлая"
        case .fragile:    "Хрупкая"
        case .frozen:     "Замороженная"
        case .double:     "Двойная"
        case .lockedLock: "Замок"
        case .lockedKey:  "Ключ"
        case .bomb:       "Бомба"
        case .chain:      "Цепная"
        }
    }

    var badge: String? {
        switch self {
        case .standard:   nil
        case .heavy:      "H"
        case .fragile:    "F"
        case .frozen:     "❄"
        case .double:     "D"
        case .lockedLock: "🔒"
        case .lockedKey:  "🔑"
        case .bomb:       "💣"
        case .chain:      "⛓"
        }
    }
}

// MARK: - Obstacle kinds

nonisolated enum ObstacleKind: String, CaseIterable, Sendable {
    case wall, gate, portal, ice, spring, destructible

    var displayName: String {
        switch self {
        case .wall:         "Стена"
        case .gate:         "Ворота"
        case .portal:       "Портал"
        case .ice:          "Лёд"
        case .spring:       "Пружина"
        case .destructible: "Разрушаемое"
        }
    }

    var glyph: String {
        switch self {
        case .wall:         "█"
        case .gate:         "║"
        case .portal:       "○"
        case .ice:          "❄"
        case .spring:       "↯"
        case .destructible: "▤"
        }
    }

    @MainActor var uiColor: Color {
        switch self {
        case .wall:         Color(hex: "#4a4a4a")
        case .gate:         Color(hex: "#1890ff")
        case .portal:       Color(hex: "#722ed1")
        case .ice:          Color(hex: "#91d5ff")
        case .spring:       Color(hex: "#73d13d")
        case .destructible: Color(hex: "#bfbfbf")
        }
    }
}

// MARK: - Goal

nonisolated enum GoalKind: String, CaseIterable, Sendable {
    case clearAll, clearWithoutMistakes, keysBeforeLocks
    case noHints, clearColorGroup, freePiece, clearInSeconds

    var displayName: String {
        switch self {
        case .clearAll:             "Очистить всё"
        case .clearWithoutMistakes: "Без ошибок"
        case .keysBeforeLocks:      "Ключи до замков"
        case .noHints:              "Без подсказок"
        case .clearColorGroup:      "Очистить группу цвета"
        case .freePiece:            "Освободить фигуру"
        case .clearInSeconds:       "За N секунд"
        }
    }

    var needsValue: Bool {
        self == .clearColorGroup || self == .clearInSeconds || self == .freePiece
    }
}

nonisolated struct LevelGoal: Sendable {
    var kind: GoalKind = .clearAll
    var valueString: String = ""
}

// MARK: - Data structs

nonisolated struct Piece: Identifiable, Sendable {
    var id: String
    var direction: Direction
    var cells: [GridCell]
    var kind: PieceKind = .standard
    var colorGroup: Int?
    var secondaryDirection: Direction?
    var frozenUnlockNeighbors: Int?
    var chainedPieceId: String?
}

nonisolated struct Obstacle: Identifiable, Sendable {
    var id: String
    var kind: ObstacleKind
    var cell: GridCell
    var parameter: String?
    var colorGroup: Int?
}

// MARK: - Editor types

enum EditorMode: Equatable {
    case piece
    case obstacle(ObstacleKind)
    case eraser

    var displayName: String {
        switch self {
        case .piece:            "Фигура"
        case .obstacle(let k):  k.displayName
        case .eraser:           "Ластик"
        }
    }

    static var allModes: [EditorMode] {
        [.piece] + ObstacleKind.allCases.map { .obstacle($0) } + [.eraser]
    }
}

enum SelectionKind { case piece, obstacle }

nonisolated enum ValidationStatus: Equatable, Sendable {
    case idle
    case checking
    case valid(moves: Int, seconds: Double)
    case invalid(reason: String)
    case unsolvable(seconds: Double)
    case skipped
}

// MARK: - Piece colors

let kPieceColors: [Color] = [
    Color(hex: "#5b8def"), Color(hex: "#ef7b7b"), Color(hex: "#52c41a"), Color(hex: "#fa8c16"),
    Color(hex: "#9254de"), Color(hex: "#13c2c2"), Color(hex: "#eb2f96"), Color(hex: "#fadb14"),
    Color(hex: "#2f54eb"), Color(hex: "#a0d911"), Color(hex: "#fa541c"), Color(hex: "#722ed1"),
]

func pieceColor(at index: Int) -> Color {
    kPieceColors[abs(index) % kPieceColors.count]
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}
