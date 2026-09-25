// Compiled by export_parrot_fixture.sh after generation. It exercises the
// exact DEBUG declaration that ScreenshotHarness consumes.

import Foundation

@main
private struct ParrotFixtureVerifier {
    static func main() throws {
        let first = ScreenshotParrotFixture.makeLevel()
        let second = ScreenshotParrotFixture.makeLevel()

        guard first == second else {
            throw VerificationError("fixture is not deterministic across loads")
        }
        guard first.id == "screenshot_photo_parrot" else {
            throw VerificationError("unexpected fixture id")
        }
        guard first.width == 102, first.height == 128 else {
            throw VerificationError("unexpected maximum-detail dimensions")
        }
        guard first.pieces.count >= 400 else {
            throw VerificationError("maximum-detail fixture is unexpectedly sparse")
        }
        guard Set(first.pieces.flatMap(\.cells)).count == 4_310 else {
            throw VerificationError("unexpected silhouette cell count")
        }
        guard first.piecePalette.count == 6 else {
            throw VerificationError("unexpected source palette count")
        }
        guard LevelSolver.solve(board: first.makeBoard())?.count == first.pieces.count else {
            throw VerificationError("fixture is not fully solvable")
        }

        print(
            "verified fixture=\(first.id) board=\(first.width)x\(first.height) "
                + "cells=4310 pieces=\(first.pieces.count) colors=\(first.piecePalette.count)"
        )
    }

    private struct VerificationError: Error, CustomStringConvertible {
        let description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
