//
//  PerformanceTrace.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//
//
//  Lightweight launch and navigation measurements. Signposts are visible in
//  Instruments, while the paired analytics events can later be forwarded by
//  the existing AnalyticsClient without changing gameplay code.
//

import Foundation
import OSLog

@MainActor
enum PerformanceTrace {
    private struct Interval {
        let startedAt: ContinuousClock.Instant
        let state: OSSignpostIntervalState
    }

    private struct LevelInterval {
        let contentID: String
        let mode: String
        let interval: Interval
    }

    private static let clock = ContinuousClock()
    private static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "zimma.MazeArrows",
        category: "Performance"
    )
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "zimma.MazeArrows",
        category: "Performance"
    )

    private static var launchInterval: Interval?
    private static var catalogInterval: Interval?
    private static var menuBackgroundInterval: Interval?
    private static var levelInterval: LevelInterval?
    private static var didReportInitialScreen = false
    private static var didReportMenuReady = false

    static func appDidStart() {
        guard launchInterval == nil, !didReportInitialScreen else { return }
        launchInterval = beginInterval(named: "Cold Launch")
        Analytics.log(.appLaunch)
    }

    static func initialScreenReady(_ screen: String) {
        guard !didReportInitialScreen else { return }
        didReportInitialScreen = true

        let duration = endInterval(named: "Cold Launch", interval: launchInterval)
        launchInterval = nil
        logger.info("Initial screen ready: \(screen, privacy: .public), \(duration) ms")
        Analytics.log(.initialScreenReady(
            screen: screen,
            durationMilliseconds: duration
        ))
    }

    static func menuReady() {
        guard !didReportMenuReady else { return }
        didReportMenuReady = true
        logger.info("Main menu ready")
        Analytics.log(.menuReady)
    }

    static func beginCatalogLoad() {
        guard catalogInterval == nil else { return }
        catalogInterval = beginInterval(named: "Level Catalog Load")
    }

    static func endCatalogLoad(levelCount: Int) {
        let duration = endInterval(
            named: "Level Catalog Load",
            interval: catalogInterval
        )
        catalogInterval = nil
        logger.info("Level catalog ready: \(levelCount) levels, \(duration) ms")
    }

    static func failCatalogLoad(_ description: String) {
        let duration = endInterval(
            named: "Level Catalog Load",
            interval: catalogInterval
        )
        catalogInterval = nil
        logger.error(
            "Level catalog failed after \(duration) ms: \(description, privacy: .public)"
        )
    }

    static func beginMenuBackgroundLoad() {
        guard menuBackgroundInterval == nil else { return }
        menuBackgroundInterval = beginInterval(named: "Menu Background Ready")
    }

    static func menuBackgroundReady() {
        let duration = endInterval(
            named: "Menu Background Ready",
            interval: menuBackgroundInterval
        )
        menuBackgroundInterval = nil
        logger.info("Menu background ready in \(duration) ms")
    }

    static func beginLevelLoad(contentID: String, mode: String) {
        if let levelInterval,
           levelInterval.contentID == contentID,
           levelInterval.mode == mode {
            return
        }

        if let previous = levelInterval {
            signposter.endInterval("Level Ready", previous.interval.state)
        }

        levelInterval = LevelInterval(
            contentID: contentID,
            mode: mode,
            interval: beginInterval(named: "Level Ready")
        )
        logger.info(
            "Level load started: \(mode, privacy: .public) / \(contentID, privacy: .public)"
        )
        Analytics.log(.levelLoadStarted(contentID: contentID, mode: mode))
    }

    static func levelReady(contentID: String, mode: String) {
        guard let levelInterval,
              levelInterval.contentID == contentID,
              levelInterval.mode == mode
        else { return }

        let duration = endInterval(
            named: "Level Ready",
            interval: levelInterval.interval
        )
        self.levelInterval = nil
        logger.info(
            "Level ready: \(mode, privacy: .public) / \(contentID, privacy: .public), \(duration) ms"
        )
        Analytics.log(.levelReady(
            contentID: contentID,
            mode: mode,
            durationMilliseconds: duration
        ))
    }

    private static func beginInterval(named name: StaticString) -> Interval {
        Interval(
            startedAt: clock.now,
            state: signposter.beginInterval(name)
        )
    }

    @discardableResult
    private static func endInterval(
        named name: StaticString,
        interval: Interval?
    ) -> Int {
        guard let interval else { return 0 }
        signposter.endInterval(name, interval.state)
        return milliseconds(from: interval.startedAt, to: clock.now)
    }

    private static func milliseconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> Int {
        let components = start.duration(to: end).components
        let wholeMilliseconds = components.seconds * 1_000
        let fractionalMilliseconds = components.attoseconds / 1_000_000_000_000_000
        return Int(clamping: wholeMilliseconds + fractionalMilliseconds)
    }
}
