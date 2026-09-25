//
//  DeterministicRandom.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Stable primitives for calendar-based content. Do not replace the hash with
//  Swift.Hasher: its seed is intentionally randomized for every process.
//

/// Deterministic FNV-1a string hash for content-generation seeds.
nonisolated func stableHash64(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

/// Deterministic RNG so calendar content matches across launches and devices.
nonisolated struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed != 0 ? seed : 0xDEADBEEFCAFEBABE
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}
