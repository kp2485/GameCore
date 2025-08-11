//
//  InteractionTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//


import Testing
@testable import GameMap
@testable import GameCore

@Suite struct InteractionTests {
    @Test
    func doorOpenAndSecretReveal() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .door(locked: false, secret: true)

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)

        // Reveal secret first
        #expect(rt.interactAhead() == .secretRevealed)
        // Door now normal, open it
        #expect(rt.interactAhead() == .doorOpened)

        var rng: any Randomizer = SeededPRNG(seed: 1)
        let moved = rt.moveForward(rng: &rng)
        #expect(moved.moved)
    }

    @Test
    func repelSuppressionSkipsEncounter() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map.regions["all"] = MapRegion(
            rects: [Rect(x: 0, y: 0, w: 2, h: 1)],
            encounter: EncounterTable(entries: [.init(weight: 1, battleId: "x")], stepsPerCheck: 1, chancePercent: 100)
        )

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east, modifiers: StepModifiers(repelEncounterPercent: 100))
        var rng: any Randomizer = SeededPRNG(seed: 2)
        let res = rt.moveForward(rng: &rng)
        #expect(res.moved)
        #expect(res.triggeredEncounterId == nil) // fully suppressed
    }
}