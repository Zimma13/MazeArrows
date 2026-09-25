//
//  LevelImportService.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Runs decoding, validation, and solving of untrusted shared levels away
//  from MainActor, with structured cancellation and a bounded execution time.
//

import Foundation

nonisolated enum LevelImportError: Error, Equatable, Sendable {
    case invalidCode
    case timedOut
}

nonisolated enum LevelImportService {
    static let defaultTimeout: Duration = .seconds(5)

    static func importLevel(
        from input: String,
        timeout: Duration = defaultTimeout
    ) async throws -> Level {
        try Task.checkCancellation()

        return try await withThrowingTaskGroup(of: Level.self) { group in
            group.addTask(priority: .userInitiated) {
                try Task.checkCancellation()
                let level = LevelShareCodec.level(fromCode: input)
                try Task.checkCancellation()
                guard let level else { throw LevelImportError.invalidCode }
                return level
            }

            group.addTask {
                try await Task.sleep(for: timeout)
                try Task.checkCancellation()
                throw LevelImportError.timedOut
            }

            defer { group.cancelAll() }
            guard let level = try await group.next() else {
                throw LevelImportError.invalidCode
            }
            return level
        }
    }
}
