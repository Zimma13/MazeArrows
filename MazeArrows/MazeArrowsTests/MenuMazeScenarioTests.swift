//
//  MenuMazeScenarioTests.swift
//  MazeArrows
//
//  Created by Zimma on 11.05.2026.
//Tests
//

import Testing
@testable import MazeArrows

struct MenuMazeScenarioTests {
    @Test func scenariosPlayInStableOrderAndLoop() {
        #expect(MenuMazeScenario.allCases == [
            .carefulSolve,
            .falseStart,
            .guidedTrail,
            .speedRun,
            .comeback
        ])

        #expect(MenuMazeScenario.carefulSolve.next == .falseStart)
        #expect(MenuMazeScenario.falseStart.next == .guidedTrail)
        #expect(MenuMazeScenario.guidedTrail.next == .speedRun)
        #expect(MenuMazeScenario.speedRun.next == .comeback)
        #expect(MenuMazeScenario.comeback.next == .carefulSolve)
    }

    @Test func everyScenarioHasAUniqueBoundedProfile() {
        let profiles = MenuMazeScenario.allCases.map(\.profile)

        #expect(Set(profiles).count == MenuMazeScenario.allCases.count)
        #expect(profiles.allSatisfy { (8...18).contains($0.maximumMoves) })
        #expect(profiles.allSatisfy { $0.initialMistakes >= 0 })
        #expect(profiles.allSatisfy { $0.minimumDelay >= 0.06 })
    }

    @Test func scenariosKeepTheirDistinctNarratives() {
        #expect(MenuMazeScenario.carefulSolve.profile.initialMistakes == 0)
        #expect(MenuMazeScenario.falseStart.profile.initialMistakes == 2)
        #expect(MenuMazeScenario.guidedTrail.profile.hintCadence == 1)
        #expect(MenuMazeScenario.speedRun.profile.hintCadence == nil)
        #expect(MenuMazeScenario.comeback.profile.mistakeMilestones == [1, 2, 6])
    }

    @Test func speedRunActuallyAcceleratesWithoutCrossingItsFloor() {
        let profile = MenuMazeScenario.speedRun.profile

        #expect(profile.regularDelay(after: 0) == 0.14)
        #expect(profile.regularDelay(after: 10) < profile.regularDelay(after: 0))
        #expect(profile.regularDelay(after: 10_000) == profile.minimumDelay)
        #expect(profile.continuationDelay(after: 10_000) == profile.minimumDelay)
    }
}
