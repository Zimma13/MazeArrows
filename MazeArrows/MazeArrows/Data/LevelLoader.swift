//
//  LevelLoader.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//

import Foundation
import Observation

nonisolated enum LevelLoaderError: Error, CustomStringConvertible, Sendable {
    case bundleResourceMissing(String)
    case resourceReadFailed(String)
    case decodingFailed(String)
    case emptyCatalog
    case invalidContinuation(String)

    var description: String {
        switch self {
        case .bundleResourceMissing(let name):
            return "Resource \(name) not found"
        case .resourceReadFailed(let message):
            return "Resource read failed: \(message)"
        case .decodingFailed(let message):
            return "Decoding failed: \(message)"
        case .emptyCatalog:
            return "Catalog contains no valid levels"
        case .invalidContinuation(let message):
            return "Invalid campaign continuation: \(message)"
        }
    }
}

/// Owns catalog I/O, decoding, sorting and solver validation. Actor isolation
/// guarantees that this work never inherits the UI's MainActor executor and
/// that simultaneous requests share one immutable cache.
actor LevelLoader {
    static let shared = LevelLoader()
    private init() {}

    private var cache: [Level]?

    func levels() throws -> [Level] {
        if let cache { return cache }
        try Task.checkCancellation()

        let legacyData = try Self.readResource("levels")
        let continuationData = try Self.readResource("levels-v2")
        let decoded = try Self.decodeCatalog(legacyData: legacyData, continuationData: continuationData)
        try Task.checkCancellation()

        // Bundled levels are solver-validated by the content pipeline and test
        // suite. Re-solving the entire catalog on every clean installation
        // competes with the first SpriteKit scene for CPU time, so launch only
        // performs the inexpensive structural safety checks.
        var valid: [Level] = []
        valid.reserveCapacity(decoded.count)
        for level in decoded {
            try Task.checkCancellation()
            if let error = LevelValidator.validateLevel(level, requireSolvable: false) {
                if case .cancelled = error { throw CancellationError() }
                #if DEBUG
                print("[LevelLoader] Skipping level \(level.id): \(error.description)")
                #endif
                continue
            }
            valid.append(level)
        }

        guard !valid.isEmpty else { throw LevelLoaderError.emptyCatalog }
        valid.sort { $0.index < $1.index }
        try Task.checkCancellation()
        cache = valid
        return valid
    }

    private static func readResource(_ name: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw LevelLoaderError.bundleResourceMissing("\(name).json")
        }
        do {
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw LevelLoaderError.resourceReadFailed(String(describing: error))
        }
    }

    /// The shipped original pack is immutable. A malformed continuation must
    /// fail explicitly rather than silently removing gates or creating holes.
    static func decodeCatalog(legacyData: Data, continuationData: Data) throws -> [Level] {
        let legacy: [Level]
        let continuation: [Level]
        do {
            legacy = try JSONDecoder().decode([Level].self, from: legacyData)
            continuation = try JSONDecoder().decode([Level].self, from: continuationData)
        } catch {
            throw LevelLoaderError.decodingFailed(String(describing: error))
        }
        guard continuation.map(\.index).sorted() == Array(241...260),
              continuation.allSatisfy({ $0.id == "story_\($0.index)" && $0.rulesVersion == 2 }),
              Set(legacy.map(\.id)).isDisjoint(with: Set(continuation.map(\.id))),
              Set(legacy.map(\.index)).isDisjoint(with: Set(continuation.map(\.index))) else {
            throw LevelLoaderError.invalidContinuation("Expected unique story_241…story_260 with rules version 2")
        }
        for level in continuation {
            try Task.checkCancellation()
            if let error = LevelValidator.validateLevel(level, requireSolvable: false) {
                if case .cancelled = error { throw CancellationError() }
                throw LevelLoaderError.invalidContinuation("\(level.id): \(error.description)")
            }
        }
        return legacy + continuation
    }
}

/// MainActor-facing snapshot used by SwiftUI. It never performs file I/O or
/// validation itself; it only publishes the Sendable values returned by the
/// background loader actor.
@MainActor
@Observable
final class LevelCatalogStore {
    static let shared = LevelCatalogStore()

    private(set) var levels: [Level] = []
    private(set) var isLoading = false
    private(set) var loadErrorDescription: String?

    @ObservationIgnored private var levelsByIndex: [Int: Level] = [:]
    @ObservationIgnored private var activeLoad: (id: UUID, task: Task<Void, Never>)?
    @ObservationIgnored private let loadLevels: @Sendable () async throws -> [Level]

    init(
        loadLevels: @escaping @Sendable () async throws -> [Level] = {
            try LevelLoader.shared.levels()
        }
    ) {
        self.loadLevels = loadLevels
    }

    var maxHandcraftedIndex: Int {
        levels.last?.index ?? 0
    }

    func level(at index: Int) -> Level? {
        // `levelsByIndex` is intentionally ignored by Observation. Reading the
        // published array here makes SwiftUI refresh destinations when the
        // first catalog load completes.
        _ = levels.count
        return levelsByIndex[index]
    }

    func loadIfNeeded() async {
        while levels.isEmpty {
            let task: Task<Void, Never>
            if let existing = activeLoad {
                task = existing.task
            } else {
                isLoading = true
                loadErrorDescription = nil
                PerformanceTrace.beginCatalogLoad()

                let requestID = UUID()
                let loadLevels = self.loadLevels
                let created = Task.detached(priority: .userInitiated) { [weak self] in
                    do {
                        let loaded = try await loadLevels()
                        await self?.completeLoad(id: requestID, levels: loaded)
                    } catch is CancellationError {
                        await self?.completeCancelledLoad(id: requestID)
                    } catch {
                        let description = String(describing: error)
                        await self?.completeLoadFailure(
                            id: requestID,
                            description: description
                        )
                    }
                }
                activeLoad = (requestID, created)
                task = created
            }

            // The store-owned task publishes its own result. Cancellation of
            // this view-bound waiter can no longer strand a completed catalog.
            await task.value

            if !levels.isEmpty || loadErrorDescription != nil { return }
        }
    }

    private func completeLoad(id: UUID, levels loaded: [Level]) {
        guard activeLoad?.id == id else { return }

        var index: [Int: Level] = [:]
        index.reserveCapacity(loaded.count)
        for level in loaded {
            index[level.index] = level
        }
        levelsByIndex = index
        levels = loaded
        PerformanceTrace.endCatalogLoad(levelCount: loaded.count)
        activeLoad = nil
        isLoading = false
    }

    private func completeCancelledLoad(id: UUID) {
        guard activeLoad?.id == id else { return }
        PerformanceTrace.failCatalogLoad("cancelled")
        activeLoad = nil
        isLoading = false
    }

    private func completeLoadFailure(id: UUID, description: String) {
        guard activeLoad?.id == id else { return }
        loadErrorDescription = description
        PerformanceTrace.failCatalogLoad(description)
        activeLoad = nil
        isLoading = false
    }
}
