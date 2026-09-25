//
//  TutorialLevelDefinition.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

enum TutorialStage: Int, Sendable {
    case one = 1
    case two
    case three
    case four
}

struct TutorialLevelDefinition: Sendable {
    let stage: TutorialStage
    let board: Board
    let initialSpotlightID: String?
    let forcedBlockedPieceID: String?
    let forcedBlockerPieceID: String?
    let comboSequence: [String]
    let startingLives: Int?

    static func definition(for stage: TutorialStage) -> TutorialLevelDefinition {
        switch stage {
        case .one: return levelOne
        case .two: return levelTwo
        case .three: return levelThree
        case .four: return levelFour
        }
    }

    static let levelOne = TutorialLevelDefinition(
        stage: .one,
        board: Board(width: 6, height: 6, pieces: [
            piece("A", [(1, 1), (0, 1)], .left, color: 0),
            piece("B", [(4, 1), (5, 1)], .right, color: 1),
            piece("C", [(2, 3), (2, 4)], .down, color: 2),
            piece("D", [(3, 3), (3, 2)], .up, color: 3)
        ]),
        initialSpotlightID: "A",
        forcedBlockedPieceID: nil,
        forcedBlockerPieceID: nil,
        comboSequence: [],
        startingLives: nil
    )

    static let levelTwo = TutorialLevelDefinition(
        stage: .two,
        board: Board(width: 6, height: 6, pieces: [
            piece("X", [(0, 3), (1, 3)], .right, color: 0),
            piece("B", [(4, 3), (4, 2)], .up, color: 1),
            piece("C", [(2, 1), (1, 1)], .left, color: 2),
            piece("D", [(3, 4), (3, 5)], .down, color: 3),
            piece("E", [(1, 0), (2, 0)], .right, color: 4)
        ]),
        initialSpotlightID: "X",
        forcedBlockedPieceID: "X",
        forcedBlockerPieceID: "B",
        comboSequence: [],
        startingLives: nil
    )

    static let levelThree = TutorialLevelDefinition(
        stage: .three,
        board: Board(width: 6, height: 6, pieces: [
            piece("A", [(4, 0), (5, 0)], .right, color: 0),
            piece("B", [(5, 2), (5, 3)], .down, color: 1),
            piece("C", [(1, 3), (1, 2)], .up, color: 2),
            piece("D", [(3, 3), (2, 3)], .left, color: 3),
            piece("E", [(3, 5), (3, 4)], .up, color: 4),
            piece("F", [(1, 5), (0, 5)], .left, color: 5)
        ]),
        initialSpotlightID: nil,
        forcedBlockedPieceID: nil,
        forcedBlockerPieceID: nil,
        comboSequence: ["C", "D", "E"],
        startingLives: nil
    )

    /// A compact, solver-verified board created for the missing L4 design.
    /// Its first X tap demonstrates a life loss; B then frees the exit lane.
    static let levelFour = TutorialLevelDefinition(
        stage: .four,
        board: Board(width: 6, height: 6, pieces: [
            piece("X", [(0, 3), (1, 3)], .right, color: 0),
            piece("B", [(4, 3), (4, 2)], .up, color: 1),
            piece("A", [(1, 0), (0, 0)], .left, color: 2),
            piece("C", [(2, 1), (3, 1)], .right, color: 3),
            piece("D", [(2, 4), (2, 5)], .down, color: 4),
            piece("E", [(4, 5), (5, 5)], .right, color: 5),
            piece("F", [(5, 1), (5, 0)], .up, color: 1),
            piece("G", [(1, 4), (0, 4)], .left, color: 2)
        ]),
        initialSpotlightID: "X",
        forcedBlockedPieceID: "X",
        forcedBlockerPieceID: "B",
        comboSequence: [],
        startingLives: 3
    )

    static func validateDefinitions() -> Bool {
        let all = [levelOne, levelTwo, levelThree, levelFour]
        guard all.allSatisfy({ LevelSolver.solve(board: $0.board) != nil }) else {
            return false
        }

        guard MoveValidator.availableMoves(board: levelOne.board).count == 4 else {
            return false
        }

        guard let levelTwoX = levelTwo.board.pieces.first(where: { $0.id == "X" }),
              let levelTwoB = levelTwo.board.pieces.first(where: { $0.id == "B" }),
              !MoveValidator.canFlyOut(piece: levelTwoX, board: levelTwo.board),
              MoveValidator.canFlyOut(piece: levelTwoB, board: levelTwo.board),
              canRemoveInOrder(["B", "X"], from: levelTwo.board)
        else { return false }

        guard let c = levelThree.board.pieces.first(where: { $0.id == "C" }),
              let d = levelThree.board.pieces.first(where: { $0.id == "D" }),
              let e = levelThree.board.pieces.first(where: { $0.id == "E" }),
              MoveValidator.canFlyOut(piece: c, board: levelThree.board),
              !MoveValidator.canFlyOut(piece: d, board: levelThree.board),
              !MoveValidator.canFlyOut(piece: e, board: levelThree.board),
              canRemoveInOrder(levelThree.comboSequence, from: levelThree.board)
        else { return false }

        guard let levelFourX = levelFour.board.pieces.first(where: { $0.id == "X" }),
              let levelFourB = levelFour.board.pieces.first(where: { $0.id == "B" }),
              !MoveValidator.canFlyOut(piece: levelFourX, board: levelFour.board),
              MoveValidator.canFlyOut(piece: levelFourB, board: levelFour.board),
              canRemoveInOrder(["B", "X"], from: levelFour.board)
        else { return false }

        return true
    }

    private static func canRemoveInOrder(_ pieceIDs: [String], from initialBoard: Board) -> Bool {
        var board = initialBoard

        for pieceID in pieceIDs {
            guard let piece = board.pieces.first(where: { $0.id == pieceID }),
                  MoveValidator.canFlyOut(piece: piece, board: board)
            else { return false }

            board.removePiece(id: pieceID)
        }

        return true
    }

    private static func piece(
        _ id: String,
        _ cells: [(Int, Int)],
        _ direction: Direction,
        color: Int
    ) -> ArrowPiece {
        ArrowPiece(
            id: id,
            cells: cells.map { GridPoint(x: $0.0, y: $0.1) },
            direction: direction,
            colorGroup: color
        )
    }
}
