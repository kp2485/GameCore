//
//  JSONLockpickTests.swift
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

private func lockDoorJSON() -> Data {
    """
    {
      "id":"floor-lock",
      "name":"Lock Test",
      "width":2,
      "height":1,
      "cells":[
        [
          { "terrain":0, "walls": [], "feature": { "kind":"none" } },
          { "terrain":0, "walls": [], "feature": { "kind":"door",
                                                   "locked": true,
                                                   "secret": false,
                                                   "lockDC": 70,
                                                   "lockSkill": "lockpicking" } }
        ]
      ],
      "regions": {}
    }
    """.data(using: .utf8)!
}

private struct SheetResolver: SkillResolver {
    let sheet: SkillSheet
    let catalog: SkillCatalog
    func check(id: SkillID, dc: Int, rng: inout any Randomizer) -> SkillOutcome {
        SkillSystem.check(id: id, sheet: sheet, catalog: catalog, dc: dc, rng: &rng)
    }
}

@Suite struct JSONLockpickTests {
    @Test @MainActor
    func importThenPickLock() throws {
        let stack = try SDStack(inMemory: true)
        let repo  = SDMapRepository(stack: stack)
        let importer = JSONMapImporter(repo: repo)
        let id = try importer.importMap(from: lockDoorJSON())
        let map = try #require(try repo.fetchMap(id: id))

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)

        // Skilled picker
        let cat = BuiltInSkills.demoCatalog()
        var sheet = SkillSheet()
        sheet.addRanks(BuiltInSkills.lockpicking, 100, using: cat)
        sheet.setBonus(BuiltInSkills.lockpicking, 20) // total = 120 → target = min(100, 120 - 10) = 100

        var rng: any Randomizer = SeededPRNG(seed: 42)
        let out = rt.interactAhead(resolver: SheetResolver(sheet: sheet, catalog: cat), rng: &rng)
        switch out {
        case .lockpickSuccess, .doorOpened: break
        default: #expect(Bool(false), "Expected to pick the lock, got \(out)")
        }
    }
}
#endif
