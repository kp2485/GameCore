//
//  JSONTrapTests.swift
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

private func trapJSON() -> Data {
    """
    {
      "id":"floor-trap",
      "name":"Trap Test",
      "width":2,
      "height":1,
      "cells":[
        [
          { "terrain":0, "walls": [], "feature": { "kind":"none" } },
          { "terrain":0, "walls": [], "feature": { "kind":"trap",
                                                   "id":"spike",
                                                   "detectDC": 40,
                                                   "disarmDC": 40,
                                                   "damage": 7,
                                                   "once": true,
                                                   "armed": true } }
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

@Suite struct JSONTrapTests {
    @Test @MainActor
    func importThenDisarm() throws {
        let stack = try SDStack(inMemory: true)
        let repo  = SDMapRepository(stack: stack)
        let importer = JSONMapImporter(repo: repo)
        _ = try importer.importMap(from: trapJSON())
        let map = try #require(try repo.fetchMap(id: "floor-trap"))

        let cat = BuiltInSkills.demoCatalog()
        var sheet = SkillSheet()
        sheet.addRanks(BuiltInSkills.perception, 85, using: cat)
        sheet.addRanks(BuiltInSkills.disarm, 85, using: cat)

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 123)
        let out = rt.interactAhead(resolver: SheetResolver(sheet: sheet, catalog: cat), rng: &rng)
        #expect(out == .trapDisarmed)
        #expect(rt.map[GridCoord(1,0)].feature == .none)
    }
}
#endif
