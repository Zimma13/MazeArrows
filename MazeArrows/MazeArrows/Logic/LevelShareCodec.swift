//
//  LevelShareCodec.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Compact level sharing: a level is packed into a tight binary blob
//  (~5 bytes + 2 bits/cell per piece), zlib-compressed and base64url-encoded
//  into a "mazearrows://l?d=..." URL small enough for a QR code. Scanning
//  the QR with the system camera opens the app straight into the level.
//
//  Binary layout (before compression), all little-endian:
//    "MZ" magic, u8 version=1 or 2
//    u8 width, u8 height, u8 lives, u8 difficultyOrder, u16 pieceCount
//    version 2 only: u8 paletteCount, then paletteCount × (u8 r, u8 g, u8 b)
//    per piece:
//      u8 kindIndex, u8 colorGroup+1 (0=nil), u8 extra, u8 cellCount
//      u8 firstX, u8 firstY, then (cellCount-1) 2-bit steps packed into bytes
//    `extra`: frozen → unlock threshold; double → secondaryDirection+1.
//    Arrow direction is not stored — it always equals the last step.
//    Version 3: "MZ", u8 version=3, followed by a complete JSON Level with
//    rulesVersion=2. This preserves gate IDs and explicit key references.
//    Versions 1 and 2 stay byte-compatible with already shared links.
//

import Foundation
import Compression

nonisolated enum LevelShareCodec {

    static let scheme = "mazearrows"

    /// Hard limits for untrusted links and pasted codes. The compressed limit
    /// is intentionally much larger than a normal shared maze while still
    /// preventing an attacker from allocating arbitrarily large Base64 data.
    static let maximumCompressedPayloadBytes = 384 * 1024
    static let maximumEncodedPayloadBytes = ((maximumCompressedPayloadBytes + 2) / 3) * 4
    static let maximumInputBytes = maximumEncodedPayloadBytes + 1024
    static let maximumDecompressedPayloadBytes = 512 * 1024
    private static let decompressionChunkBytes = 32 * 1024

    private static let kindOrder: [PieceKind] = [
        .standard, .heavy, .fragile, .frozen, .double,
        .lockedLock, .lockedKey, .bomb, .chain,
    ]
    private static let directionOrder: [Direction] = [.up, .down, .left, .right]

    // MARK: - public API

    static func shareURL(for level: Level) -> URL? {
        guard let data = encode(level),
              data.count <= maximumCompressedPayloadBytes
        else { return nil }
        return URL(string: "\(scheme)://l?d=\(base64URL(data))")
    }

    static func level(from url: URL) -> Level? {
        guard !Task.isCancelled,
              inputSizeIsAllowed(url.absoluteString),
              url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "d" })?.value
        else { return nil }
        guard let data = dataFromBase64URL(code) else { return nil }
        return decode(data)
    }

    /// Accepts a bare code or a full pasted URL.
    static func level(fromCode code: String) -> Level? {
        guard !Task.isCancelled, inputSizeIsAllowed(code) else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !Task.isCancelled else { return nil }
        if trimmed.contains("://") {
            guard let url = URL(string: trimmed) else { return nil }
            return level(from: url)
        }
        guard let data = dataFromBase64URL(trimmed) else { return nil }
        return decode(data)
    }

    // MARK: - encode

    static func encode(_ level: Level) -> Data? {
        if level.rulesVersion == 2 { return encodeVersionTwoLevel(level) }
        guard level.rulesVersion == 1 else { return nil }
        guard level.width > 0, level.width <= 255,
              level.height > 0, level.height <= 255,
              !level.pieces.isEmpty, level.pieces.count <= 65535,
              level.piecePalette.count <= 255
        else { return nil }

        var out = Data()
        let version: UInt8 = level.piecePalette.isEmpty ? 1 : 2
        out.append(contentsOf: [0x4D, 0x5A, version])
        out.append(UInt8(level.width))
        out.append(UInt8(level.height))
        out.append(UInt8(max(1, min(255, level.lives))))
        out.append(UInt8(level.difficulty.order))
        out.append(UInt8(level.pieces.count & 0xFF))
        out.append(UInt8(level.pieces.count >> 8))

        if version == 2 {
            out.append(UInt8(level.piecePalette.count))
            for color in level.piecePalette {
                out.append(colorByte(color.red))
                out.append(colorByte(color.green))
                out.append(colorByte(color.blue))
            }
        }

        for piece in level.pieces {
            guard let kindIndex = kindOrder.firstIndex(of: piece.kind),
                  piece.cells.count >= 2, piece.cells.count <= 255,
                  let first = piece.cells.first,
                  first.x >= 0, first.x <= 255, first.y >= 0, first.y <= 255
            else { return nil }

            let group = (piece.colorGroup ?? -1) + 1
            guard group >= 0, group <= 255 else { return nil }
            if version == 2,
               let colorGroup = piece.colorGroup,
               colorGroup > level.piecePalette.count {
                return nil
            }

            let extra: Int
            switch piece.kind {
            case .frozen:
                extra = piece.frozenUnlockNeighbors ?? 1
            case .double:
                extra = piece.secondaryDirection
                    .flatMap { directionOrder.firstIndex(of: $0) }
                    .map { $0 + 1 } ?? 0
            default:
                extra = 0
            }

            out.append(UInt8(kindIndex))
            out.append(UInt8(group))
            out.append(UInt8(max(0, min(255, extra))))
            out.append(UInt8(piece.cells.count))
            out.append(UInt8(first.x))
            out.append(UInt8(first.y))

            var stepByte: UInt8 = 0
            var stepsInByte = 0
            for i in 1..<piece.cells.count {
                let a = piece.cells[i - 1]
                let b = piece.cells[i]
                guard let step = stepIndex(dx: b.x - a.x, dy: b.y - a.y) else { return nil }
                stepByte |= UInt8(step) << (stepsInByte * 2)
                stepsInByte += 1
                if stepsInByte == 4 {
                    out.append(stepByte)
                    stepByte = 0
                    stepsInByte = 0
                }
            }
            if stepsInByte > 0 { out.append(stepByte) }
        }

        return (try? (out as NSData).compressed(using: .zlib)) as Data?
    }

    private static func encodeVersionTwoLevel(_ level: Level) -> Data? {
        guard !Task.isCancelled,
              LevelValidator.validateLevel(level, requireSolvable: true) == nil,
              let json = try? JSONEncoder().encode(level),
              json.count <= maximumDecompressedPayloadBytes - 3 else { return nil }
        var payload = Data([0x4D, 0x5A, 3])
        payload.append(json)
        guard let compressed = (try? (payload as NSData).compressed(using: .zlib)) as Data?,
              compressed.count <= maximumCompressedPayloadBytes else { return nil }
        return compressed
    }

    // MARK: - decode

    static func decode(_ data: Data) -> Level? {
        guard !Task.isCancelled,
              !data.isEmpty,
              data.count <= maximumCompressedPayloadBytes
        else { return nil }
        guard let raw = decompressZlib(data) else { return nil }
        var index = 0
        func take() -> UInt8? {
            guard index < raw.count else { return nil }
            defer { index += 1 }
            return raw[raw.startIndex + index]
        }

        guard take() == 0x4D, take() == 0x5A,
              let version = take(), version == 1 || version == 2 || version == 3
        else { return nil }
        if version == 3 {
            return decodeVersionTwoLevel(Data(raw.dropFirst(3)), compressed: data)
        }
        guard let width = take().map(Int.init), width > 0,
              let height = take().map(Int.init), height > 0,
              let lives = take().map(Int.init),
              let difficultyOrder = take().map(Int.init),
              let countLow = take().map(Int.init),
              let countHigh = take().map(Int.init)
        else { return nil }
        let pieceCount = countLow | (countHigh << 8)
        guard pieceCount > 0, pieceCount <= 4096 else { return nil }

        var piecePalette: [PieceGroupPaletteColor] = []
        if version == 2 {
            guard let paletteCount = take().map(Int.init), paletteCount > 0 else { return nil }
            piecePalette.reserveCapacity(paletteCount)
            for _ in 0..<paletteCount {
                guard let red = take(), let green = take(), let blue = take() else { return nil }
                piecePalette.append(PieceGroupPaletteColor(
                    red: Double(red) / 255,
                    green: Double(green) / 255,
                    blue: Double(blue) / 255
                ))
            }
        }

        var pieces: [ArrowPiece] = []
        pieces.reserveCapacity(pieceCount)
        for pieceNumber in 1...pieceCount {
            guard !Task.isCancelled else { return nil }
            guard let kindIndex = take().map(Int.init), kindIndex < kindOrder.count,
                  let groupRaw = take().map(Int.init),
                  let extra = take().map(Int.init),
                  let cellCount = take().map(Int.init), cellCount >= 2,
                  let startX = take().map(Int.init),
                  let startY = take().map(Int.init)
            else { return nil }
            let kind = kindOrder[kindIndex]
            if version == 2, groupRaw > 0, groupRaw - 1 > piecePalette.count {
                return nil
            }

            var cells = [GridPoint(x: startX, y: startY)]
            var stepByte: UInt8 = 0
            var stepsLeftInByte = 0
            var lastStep = 0
            for cellIndex in 1..<cellCount {
                if cellIndex.isMultiple(of: 64), Task.isCancelled { return nil }
                if stepsLeftInByte == 0 {
                    guard let byte = take() else { return nil }
                    stepByte = byte
                    stepsLeftInByte = 4
                }
                let step = Int(stepByte & 0b11)
                stepByte >>= 2
                stepsLeftInByte -= 1
                lastStep = step
                let previous = cells[cells.count - 1]
                let direction = directionOrder[step]
                cells.append(GridPoint(x: previous.x + direction.dx, y: previous.y + direction.dy))
            }

            let direction = directionOrder[lastStep]
            pieces.append(ArrowPiece(
                id: "sh_\(pieceNumber)",
                cells: cells,
                direction: direction,
                kind: kind,
                colorGroup: groupRaw == 0 ? nil : groupRaw - 1,
                secondaryDirection: kind == .double && extra > 0 && extra <= 4
                    ? directionOrder[extra - 1] : nil,
                frozenUnlockNeighbors: kind == .frozen ? max(1, extra) : nil
            ))
        }

        guard let dataHash = fnv(data) else { return nil }
        let difficulty = Difficulty.allCases.first { $0.order == difficultyOrder } ?? .medium
        let level = Level(
            id: "shared_\(dataHash)",
            index: 0,
            difficulty: difficulty,
            width: width,
            height: height,
            lives: max(1, lives),
            pieces: pieces,
            piecePalette: piecePalette,
            threeStarMaxMistakes: 0,
            twoStarMaxMistakes: max(1, pieces.count / 5),
            name: String(localized: "Shared Maze")
        )
        // A pasted code is untrusted input — reject anything malformed or
        // unsolvable instead of crashing mid-game.
        guard !Task.isCancelled else { return nil }
        guard LevelValidator.validateLevel(level, requireSolvable: true) == nil else { return nil }
        guard !Task.isCancelled else { return nil }
        return level
    }

    private static func decodeVersionTwoLevel(_ json: Data, compressed: Data) -> Level? {
        guard !Task.isCancelled,
              let source = try? JSONDecoder().decode(Level.self, from: json),
              source.rulesVersion == 2,
              LevelValidator.validateLevel(source, requireSolvable: true) == nil,
              let hash = fnv(compressed) else { return nil }
        // Imported content remains a shared puzzle. Never carry the story
        // index or tutorial/reward eligibility out of the encoded source.
        return Level(
            id: "shared_\(hash)", index: 0, difficulty: source.difficulty,
            width: source.width, height: source.height, lives: source.lives,
            pieces: source.pieces, piecePalette: source.piecePalette,
            obstacles: source.obstacles, goal: source.goal,
            threeStarMaxMistakes: source.threeStarMaxMistakes,
            twoStarMaxMistakes: source.twoStarMaxMistakes,
            name: String(localized: "Shared Maze"), rulesVersion: source.rulesVersion
        )
    }

    // MARK: - helpers

    /// Expands untrusted zlib data incrementally. The destination passed to
    /// Compression is never larger than the remaining allowance plus one byte,
    /// so an oversized stream is rejected without materializing its contents.
    private static func decompressZlib(_ data: Data) -> Data? {
        data.withUnsafeBytes { sourceBuffer -> Data? in
            guard let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }

            let destination = UnsafeMutablePointer<UInt8>.allocate(
                capacity: decompressionChunkBytes
            )
            defer { destination.deallocate() }

            var stream = compression_stream(
                dst_ptr: destination,
                dst_size: 0,
                src_ptr: source,
                src_size: sourceBuffer.count,
                state: nil
            )
            guard compression_stream_init(
                &stream,
                COMPRESSION_STREAM_DECODE,
                COMPRESSION_ZLIB
            ) != COMPRESSION_STATUS_ERROR else {
                return nil
            }
            defer { compression_stream_destroy(&stream) }

            stream.src_ptr = source
            stream.src_size = sourceBuffer.count

            var output = Data()
            while true {
                guard !Task.isCancelled else { return nil }
                let remaining = maximumDecompressedPayloadBytes - output.count
                let destinationSize = min(decompressionChunkBytes, remaining + 1)
                stream.dst_ptr = destination
                stream.dst_size = destinationSize

                let previousSourceSize = stream.src_size
                let status = compression_stream_process(&stream, 0)
                guard status != COMPRESSION_STATUS_ERROR else { return nil }

                let produced = destinationSize - stream.dst_size
                guard produced <= remaining else { return nil }
                if produced > 0 {
                    output.append(destination, count: produced)
                }

                if status == COMPRESSION_STATUS_END {
                    return output
                }

                // A valid decoder must consume input or produce output on every
                // non-terminal pass. This also prevents a malformed stream from
                // keeping the loop alive indefinitely.
                guard produced > 0 || stream.src_size < previousSourceSize else {
                    return nil
                }
            }
        }
    }

    private static func stepIndex(dx: Int, dy: Int) -> Int? {
        directionOrder.firstIndex { $0.dx == dx && $0.dy == dy }
    }

    private static func colorByte(_ component: Double) -> UInt8 {
        UInt8((min(1, max(0, component)) * 255).rounded())
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func dataFromBase64URL(_ string: String) -> Data? {
        let encodedCount = string.utf8.count
        guard encodedCount > 0,
              encodedCount <= maximumEncodedPayloadBytes
        else { return nil }

        var paddingCount = 0
        var sawPadding = false
        for byte in string.utf8 {
            guard !Task.isCancelled else { return nil }
            switch byte {
            case 65...90, 97...122, 48...57, 43, 45, 47, 95:
                guard !sawPadding else { return nil }
            case 61:
                sawPadding = true
                paddingCount += 1
                guard paddingCount <= 2 else { return nil }
            default:
                return nil
            }
        }

        let unpaddedCount = encodedCount - paddingCount
        guard unpaddedCount > 0,
              unpaddedCount % 4 != 1
        else { return nil }
        let decodedUpperBound = (unpaddedCount * 3 + 3) / 4
        guard decodedUpperBound <= maximumCompressedPayloadBytes else { return nil }

        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              data.count <= maximumCompressedPayloadBytes
        else { return nil }
        return data
    }

    static func inputSizeIsAllowed(_ string: String) -> Bool {
        string.utf8.count <= maximumInputBytes
    }

    private static func fnv(_ data: Data) -> String? {
        var hash: UInt64 = 0xcbf29ce484222325
        for (index, byte) in data.enumerated() {
            if index.isMultiple(of: 4096), Task.isCancelled { return nil }
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 36)
    }
}
