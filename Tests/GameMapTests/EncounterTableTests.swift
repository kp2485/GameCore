//
//  EncounterTableTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
import Foundation
@testable import GameMap
@testable import GameCore

@Suite struct EncounterTableTests {
    @Test func weightedPickDeterministic() {
        var rng: any Randomizer = SeededPRNG(seed: 123)
        let table = EncounterTable(
            entries: [
                .init(weight: 1, battleId: "slime"),
                .init(weight: 3, battleId: "rat"),
                .init(weight: 6, battleId: "wolf")
            ],
            stepsPerCheck: 1,
            chancePercent: 100
        )
        var counts: [String:Int] = [:]
        for step in 1...1000 {
            if let id = table.roll(stepCount: step, rng: &rng) {
                counts[id, default: 0] += 1
            }
        }
        // Heaviest weight should dominate
        #expect((counts["wolf"] ?? 0) > (counts["rat"] ?? 0))
        #expect((counts["rat"] ?? 0) > (counts["slime"] ?? 0))
    }

    @Test func stepsPerCheckAndChancePercentWork() {
        var rng: any Randomizer = SeededPRNG(seed: 1)
        let table = EncounterTable(entries: [.init(weight: 1, battleId: "x")], stepsPerCheck: 5, chancePercent: 50)
        var triggers = 0
        for step in 1...50 {
            if let _ = table.roll(stepCount: step, rng: &rng) { triggers += 1 }
        }
        // At most one check every 5 steps → at most 10 checks, each 50%
        #expect(triggers <= 10)
    }
}
