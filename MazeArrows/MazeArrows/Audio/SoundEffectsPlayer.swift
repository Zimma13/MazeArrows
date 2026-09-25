//
//  SoundEffectsPlayer.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Small procedural effects keep the app self-contained. Every AVAudioPlayer
//  is bounded by a short cleanup task and is released after playback, on mute,
//  or when the app leaves the foreground.
//

import AVFoundation
import Foundation

nonisolated enum GameSoundEffect: Hashable, Sendable {
    case move
    case blocked
    case victory
    case failure
}

@MainActor
final class SoundEffectsPlayer {
    static let shared = SoundEffectsPlayer()

    private static let maximumConcurrentPlayers = 8

    private var isEnabled = true
    private var isSessionActive = false
    private var activePlayers: [UUID: AVAudioPlayer] = [:]
    private var cleanupTasks: [UUID: Task<Void, Never>] = [:]
    private var soundCache: [GameSoundEffect: Data] = [:]

    private init() {}

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            stopAll()
        }
    }

    func play(_ effect: GameSoundEffect) {
        guard isEnabled else { return }
        pruneFinishedPlayers()
        trimPlayerPoolIfNeeded()
        guard activateSessionIfNeeded() else { return }

        let data = soundCache[effect] ?? Self.makeWaveData(for: effect)
        soundCache[effect] = data

        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = 0.24
            player.prepareToPlay()

            let id = UUID()
            activePlayers[id] = player
            guard player.play() else {
                activePlayers[id] = nil
                deactivateSessionIfIdle()
                return
            }

            let cleanupDelay = Duration.milliseconds(
                Int64((player.duration + 0.10) * 1_000)
            )
            cleanupTasks[id] = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: cleanupDelay)
                } catch {
                    return
                }
                guard let self else { return }
                self.activePlayers[id]?.stop()
                self.activePlayers[id] = nil
                self.cleanupTasks[id] = nil
                self.deactivateSessionIfIdle()
            }
        } catch {
            deactivateSessionIfIdle()
        }
    }

    /// Called for scene inactivity/background transitions.
    func suspend() {
        stopAll()
    }

    /// Ends effects owned by a game session without disabling future sounds.
    func stop() {
        stopAll()
    }

    private func stopAll() {
        let tasks = Array(cleanupTasks.values)
        cleanupTasks.removeAll(keepingCapacity: false)
        tasks.forEach { $0.cancel() }

        let players = Array(activePlayers.values)
        activePlayers.removeAll(keepingCapacity: false)
        players.forEach { $0.stop() }
        deactivateSession()
    }

    private func pruneFinishedPlayers() {
        let finished = activePlayers.compactMap { id, player in
            player.isPlaying ? nil : id
        }
        for id in finished {
            cleanupTasks[id]?.cancel()
            cleanupTasks[id] = nil
            activePlayers[id] = nil
        }
        deactivateSessionIfIdle()
    }

    private func trimPlayerPoolIfNeeded() {
        while activePlayers.count >= Self.maximumConcurrentPlayers,
              let id = activePlayers.keys.first {
            cleanupTasks[id]?.cancel()
            cleanupTasks[id] = nil
            activePlayers[id]?.stop()
            activePlayers[id] = nil
        }
    }

    private func activateSessionIfNeeded() -> Bool {
        guard !isSessionActive else { return true }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isSessionActive = true
            return true
        } catch {
            isSessionActive = false
            return false
        }
    }

    private func deactivateSessionIfIdle() {
        guard activePlayers.isEmpty else { return }
        deactivateSession()
    }

    private func deactivateSession() {
        guard isSessionActive else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        isSessionActive = false
    }

    // MARK: - Procedural wave generation

    private struct ToneSegment {
        let startFrequency: Double
        let endFrequency: Double
        let duration: Double
        let amplitude: Double
    }

    private static func makeWaveData(for effect: GameSoundEffect) -> Data {
        let segments: [ToneSegment]
        switch effect {
        case .move:
            segments = [.init(startFrequency: 620, endFrequency: 860, duration: 0.075, amplitude: 0.55)]
        case .blocked:
            segments = [.init(startFrequency: 190, endFrequency: 105, duration: 0.13, amplitude: 0.62)]
        case .victory:
            segments = [
                .init(startFrequency: 523.25, endFrequency: 523.25, duration: 0.09, amplitude: 0.48),
                .init(startFrequency: 659.25, endFrequency: 659.25, duration: 0.09, amplitude: 0.50),
                .init(startFrequency: 783.99, endFrequency: 880.00, duration: 0.16, amplitude: 0.55),
            ]
        case .failure:
            segments = [
                .init(startFrequency: 280, endFrequency: 220, duration: 0.11, amplitude: 0.50),
                .init(startFrequency: 205, endFrequency: 120, duration: 0.18, amplitude: 0.58),
            ]
        }

        let sampleRate = 44_100
        var samples: [Int16] = []
        samples.reserveCapacity(Int(segments.reduce(0) { $0 + $1.duration } * Double(sampleRate)))
        var phase = 0.0

        for segment in segments {
            let count = max(1, Int(segment.duration * Double(sampleRate)))
            let attackSamples = max(1, min(count / 3, Int(0.008 * Double(sampleRate))))
            let releaseSamples = max(1, min(count / 2, Int(0.025 * Double(sampleRate))))

            for index in 0..<count {
                let progress = Double(index) / Double(max(1, count - 1))
                let frequency = segment.startFrequency
                    + (segment.endFrequency - segment.startFrequency) * progress
                phase += 2 * Double.pi * frequency / Double(sampleRate)

                let attack = min(1, Double(index) / Double(attackSamples))
                let remaining = count - index - 1
                let release = min(1, Double(remaining) / Double(releaseSamples))
                let envelope = max(0, min(attack, release))
                let wave = sin(phase) + 0.12 * sin(phase * 2)
                let normalized = max(-1, min(1, wave * segment.amplitude * envelope))
                samples.append(Int16(normalized * Double(Int16.max)))
            }
        }

        return makePCM16Wave(samples: samples, sampleRate: sampleRate)
    }

    private static func makePCM16Wave(samples: [Int16], sampleRate: Int) -> Data {
        var pcm = Data(capacity: samples.count * MemoryLayout<Int16>.size)
        for sample in samples {
            pcm.appendLittleEndian(sample)
        }

        var wave = Data()
        wave.appendASCII("RIFF")
        wave.appendLittleEndian(UInt32(36 + pcm.count))
        wave.appendASCII("WAVE")
        wave.appendASCII("fmt ")
        wave.appendLittleEndian(UInt32(16))
        wave.appendLittleEndian(UInt16(1))
        wave.appendLittleEndian(UInt16(1))
        wave.appendLittleEndian(UInt32(sampleRate))
        wave.appendLittleEndian(UInt32(sampleRate * MemoryLayout<Int16>.size))
        wave.appendLittleEndian(UInt16(MemoryLayout<Int16>.size))
        wave.appendLittleEndian(UInt16(16))
        wave.appendASCII("data")
        wave.appendLittleEndian(UInt32(pcm.count))
        wave.append(pcm)
        return wave
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
