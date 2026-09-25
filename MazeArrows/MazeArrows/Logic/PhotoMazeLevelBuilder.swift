//
//  PhotoMazeLevelBuilder.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation

nonisolated enum PhotoMazeLevelBuilder {
    static func updates(for mask: ImageBoardResult) -> AsyncStream<PhotoMazeBuildUpdate> {
        AsyncStream { continuation in
            let worker = Task.detached(priority: .userInitiated) {
                let level = buildLevel(from: mask) { progress in
                    continuation.yield(.progress(progress))
                }
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                continuation.yield(.finished(level))
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                worker.cancel()
            }
        }
    }

    /// Reports work already completed. There are no artificial waits, so the
    /// percentage reflects mask preparation, partition attempts, and solving.
    private static func buildLevel(
        from mask: ImageBoardResult,
        reportProgress: @Sendable (Double) -> Void
    ) -> Level? {
        guard !Task.isCancelled else { return nil }
        reportProgress(0)

        var rng = SystemRandomNumberGenerator()
        let config = SnakeFillConfig(
            minLength: 2,
            maxLength: 9,
            straightBias: 0.55,
            chainBias: 0.7
        )

        #if DEBUG
        print("[PhotoLevel] build: grid \(mask.width)x\(mask.height), zones \(mask.zones.map(\.count))")
        #endif

        let mergedZones = [mask.allCells]
        let piecePalette = mask.zoneColors.map {
            PieceGroupPaletteColor(red: $0.r, green: $0.g, blue: $0.b)
        }
        var zoneOfCell: [GridPoint: Int] = [:]
        for (zoneIndex, zone) in mask.zones.enumerated() {
            guard !Task.isCancelled else { return nil }
            for cell in zone {
                guard !Task.isCancelled else { return nil }
                zoneOfCell[cell] = zoneIndex
            }
        }
        reportProgress(0.12)

        let attemptCount = 48
        for attempt in 0..<attemptCount {
            guard !Task.isCancelled else { return nil }
            let completedAttempts = Double(attempt) / Double(attemptCount)
            reportProgress(0.12 + completedAttempts * 0.83)

            let usingMergedZones = attempt >= 8
            let zones = usingMergedZones ? mergedZones : mask.zones
            guard var pieces = SnakeFillGenerator.makePieces(
                zones: zones,
                boardWidth: mask.width,
                boardHeight: mask.height,
                config: config,
                idPrefix: "p",
                colorGroups: true,
                rng: &rng
            ) else { continue }

            for index in pieces.indices {
                guard !Task.isCancelled else { return nil }
                if !usingMergedZones, let zone = pieces[index].colorGroup {
                    pieces[index].colorGroup = zone + 1
                } else {
                    var counts = [Int](repeating: 0, count: mask.zones.count)
                    for cell in pieces[index].cells {
                        if let zone = zoneOfCell[cell] {
                            counts[zone] += 1
                        }
                    }
                    let majority = counts.indices.max { counts[$0] < counts[$1] } ?? 0
                    pieces[index].colorGroup = majority + 1
                }
            }

            reportProgress(0.12 + (Double(attempt) + 0.7) / Double(attemptCount) * 0.83)
            let board = Board(width: mask.width, height: mask.height, pieces: pieces)
            guard LevelSolver.solve(board: board) != nil else { continue }
            guard !Task.isCancelled else { return nil }

            reportProgress(1)
            return Level(
                id: "photo_\(UUID().uuidString)",
                index: 0,
                difficulty: .medium,
                width: mask.width,
                height: mask.height,
                lives: 5,
                pieces: pieces,
                piecePalette: piecePalette,
                threeStarMaxMistakes: 0,
                twoStarMaxMistakes: max(1, pieces.count / 5),
                name: String(localized: "Photo Maze")
            )
        }

        reportProgress(1)
        return nil
    }
}
