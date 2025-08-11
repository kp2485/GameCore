//
//  MapServiceTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData) && canImport(GameMap)
import Foundation
import Testing
@testable import GameCore
@testable import GameMap
@testable import GameDataSwiftData

private func tinyCorridor() -> GameMap {
    var m = GameMap(id: "floor1", name: "Floor 1", width: 3, height: 1, fill: Cell())
    // Edge wall on west of (1,0)
    m[GridCoord(0,0)].walls.insert(.east)
    // Region at far right with guaranteed encounter
    m.regions["right"] = MapRegion(
        rects: [Rect(x: 2, y: 0, w: 1, h: 1)],
        encounter: EncounterTable(entries: [.init(weight: 1, battleId: "slime")],
                                  stepsPerCheck: 1, chancePercent: 100)
    )
    return m
}

@Suite struct MapServiceTests {

    @Test @MainActor
    func loadRevealMovePersistsFog_andRegionsTrigger() throws {
        let stack = try SDStack(inMemory: true)
        let repo = SDMapRepository(stack: stack)

        // Persist map with regions
        let map = tinyCorridor()
        try repo.upsert(map)

        let svc = MapService(maps: repo, saveId: UUID())
        try svc.load(mapId: "floor1", start: GridCoord(0,0), facing: .east)

        // Initial reveal (wall visible but blocks beyond)
        _ = try svc.revealCurrentFOV(radius: 1)

        var rng: any Randomizer = SeededPRNG(seed: 1)

        // First move blocked by edge wall
        let r0 = try svc.moveForward(rng: &rng, autoRevealRadius: 1)
        #expect(!r0.moved)

        // Open the edge and upsert cells; reload
        var map2 = map
        map2[GridCoord(0,0)].walls.remove(.east)
        try repo.upsert(map2)
        try svc.load(mapId: "floor1", start: GridCoord(0,0), facing: .east)

        // Move into (1,0)
        let r1 = try svc.moveForward(rng: &rng, autoRevealRadius: 1)
        #expect(r1.moved && r1.position == GridCoord(1,0))

        // Move into region at (2,0) → should trigger encounter
        let r2 = try svc.moveForward(rng: &rng, autoRevealRadius: 1)
        #expect(r2.moved && r2.position == GridCoord(2,0))
        #expect(r2.triggeredEncounterId == "slime")
    }
}
#endif
