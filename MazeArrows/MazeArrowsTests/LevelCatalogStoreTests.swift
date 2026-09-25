//
//  LevelCatalogStoreTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Foundation
import Testing
@testable import MazeArrows

private actor RetryingLevelLoader {
    private var attempt = 0
    private let level: Level

    init(level: Level) {
        self.level = level
    }

    func load() throws -> [Level] {
        attempt += 1
        if attempt == 1 {
            throw CancellationError()
        }
        return [level]
    }

    func attemptCount() -> Int {
        attempt
    }
}

@MainActor
struct LevelCatalogStoreTests {
    @Test func bundledCatalogPassesFullSolvabilityValidation() throws {
        let resourceURL = try #require(
            Bundle.main.url(forResource: "levels", withExtension: "json")
        )
        let data = try Data(contentsOf: resourceURL, options: [.mappedIfSafe])
        let levels = try JSONDecoder().decode([Level].self, from: data)

        #expect(!levels.isEmpty)
        for level in levels {
            if let error = LevelValidator.validateLevel(level, requireSolvable: true) {
                Issue.record("Bundled level \(level.id) is invalid: \(error.description)")
            }
        }
    }

    @Test func interruptedInitialLoadRetriesWithoutLeavingInfiniteSpinner() async {
        let level = Level(
            id: "retry-level",
            index: 1,
            difficulty: .easy,
            width: 2,
            height: 2,
            lives: 3,
            pieces: [
                ArrowPiece(
                    id: "arrow",
                    cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)],
                    direction: .left
                )
            ]
        )
        let loader = RetryingLevelLoader(level: level)
        let store = LevelCatalogStore {
            try await loader.load()
        }

        await store.loadIfNeeded()

        #expect(store.level(at: 1) == level)
        #expect(!store.isLoading)
        #expect(store.loadErrorDescription == nil)
        #expect(await loader.attemptCount() == 2)
    }

    @Test func cancelledFirstWaiterStillStartsStoreOwnedLoad() async {
        let level = Level(
            id: "cancelled-waiter-level",
            index: 2,
            difficulty: .easy,
            width: 2,
            height: 2,
            lives: 3,
            pieces: [
                ArrowPiece(
                    id: "arrow",
                    cells: [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)],
                    direction: .left
                )
            ]
        )
        let store = LevelCatalogStore { [level] in [level] }

        let firstWaiter = Task { @MainActor in
            await store.loadIfNeeded()
        }
        firstWaiter.cancel()
        await firstWaiter.value

        #expect(store.level(at: 2) == level)
        #expect(!store.isLoading)
    }
}
