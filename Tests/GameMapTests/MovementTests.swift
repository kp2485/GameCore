//
//  MovementTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameMap
@testable import GameCore

private func blankMap(_ w: Int, _ h: Int) -> GameMap {
    GameMap(id: "m", name: "M", width: w, height: h, fill: Cell(), regions: [:])
}

@Suite struct MovementTests {

    @Test
    func turningDoesNotMove() {
        var rt = MapRuntime(map: blankMap(3,3), start: GridCoord(1,1), facing: .north)
        let r1 = rt.turnLeft()
        #expect(!r1.moved)
        #expect(r1.position == GridCoord(1,1))
        #expect(r1.facing == .west)

        let r2 = rt.turnRight()
        #expect(!r2.moved)
        #expect(r2.position == GridCoord(1,1))
        #expect(r2.facing == .north)
    }

    @Test
    func moveBlockedByWall() {
        var map = blankMap(3,1)
        // Wall east of (0,0) blocks moving east from (0,0)
        map[GridCoord(0,0)].walls.insert(.east)
        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 1)
        let res = rt.moveForward(rng: &rng)
        #expect(!res.moved)
        #expect(rt.position == GridCoord(0,0))
        #expect(rt.steps == 0)
        #expect(res.triggeredEncounterId == nil)
    }

    @Test
    func moveSucceedsAndStepsIncrement() {
        let map = blankMap(3,1)
        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 1)
        let res = rt.moveForward(rng: &rng)
        #expect(res.moved)
        #expect(rt.position == GridCoord(1,0))
        #expect(rt.steps == 1)
        #expect(res.triggeredEncounterId == nil)
    }

    @Test
    func encounterRollsFromRegion() {
        // Build a 1x3 corridor with the center tile assigned to a region that always triggers encounters.
        var map = blankMap(3,1)
        let always = EncounterTable(entries: [.init(weight: 1, battleId: "slime")],
                                    stepsPerCheck: 1,
                                    chancePercent: 100)
        map.regions["corridor"] = MapRegion(rects: [Rect(x: 1, y: 0, w: 1, h: 1)], encounter: always)

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 42)

        // Step 1: move into the region → should trigger
        let r1 = rt.moveForward(rng: &rng)
        #expect(r1.moved)
        #expect(r1.triggeredEncounterId == "slime")
        #expect(rt.steps == 1)

        // Step 2: move out of the region → no region, no roll
        let r2 = rt.moveForward(rng: &rng)
        #expect(r2.moved)
        #expect(r2.triggeredEncounterId == nil)
        #expect(rt.steps == 2)
    }

    @Test
    func encounterRespectsStepsPerCheck() {
        // Trigger only on every 3rd step, 100% chance then.
        var map = blankMap(5,1)
        let table = EncounterTable(entries: [.init(weight: 1, battleId: "wolf")],
                                   stepsPerCheck: 3,
                                   chancePercent: 100)
        map.regions["strip"] = MapRegion(rects: [Rect(x: 0, y: 0, w: 5, h: 1)], encounter: table)

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 7)

        let r1 = rt.moveForward(rng: &rng) // step 1 → no
        let r2 = rt.moveForward(rng: &rng) // step 2 → no
        let r3 = rt.moveForward(rng: &rng) // step 3 → yes
        #expect(r1.triggeredEncounterId == nil)
        #expect(r2.triggeredEncounterId == nil)
        #expect(r3.triggeredEncounterId == "wolf")
        #expect(rt.steps == 3)
    }
}
