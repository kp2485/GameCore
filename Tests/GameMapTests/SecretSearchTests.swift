//
//  SecretSearchTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameMap
@testable import GameCore

private struct SheetResolver: SkillResolver {
    let sheet: SkillSheet
    let catalog: SkillCatalog
    func check(id: SkillID, dc: Int, rng: inout any Randomizer) -> SkillOutcome {
        SkillSystem.check(id: id, sheet: sheet, catalog: catalog, dc: dc, rng: &rng)
    }
}

@Suite struct SecretSearchTests {

    @Test
    func secretEdge_RevealedWithPerception() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        // Put secret edge on east edge of (0,0)
        map[GridCoord(0,0)].walls.insert(.secret)

        let cat = BuiltInSkills.demoCatalog()
        var sheet = SkillSheet()
        sheet.addRanks(BuiltInSkills.perception, 95, using: cat) // strong finder

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 1)
        let out = rt.interactAhead(resolver: SheetResolver(sheet: sheet, catalog: cat), rng: &rng)
        #expect(out == .secretRevealed)

        // After reveal, edge should not block movement anymore (unless a real wall/door exists)
        #expect(!Navigation.edgeBlocked(from: GridCoord(0,0), toward: .east, on: rt.map))
    }

    @Test
    func secretEdge_NotFoundWithLowPerception() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(0,0)].walls.insert(.secret)

        let cat = BuiltInSkills.demoCatalog()
        var sheet = SkillSheet()
        sheet.addRanks(BuiltInSkills.perception, 5, using: cat) // weak finder

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 42)
        let out = rt.interactAhead(resolver: SheetResolver(sheet: sheet, catalog: cat), rng: &rng)
        #expect(out == .secretNotFound)

        // Without reveal, edge remains blocked
        #expect(Navigation.edgeBlocked(from: GridCoord(0,0), toward: .east, on: rt.map))
    }
}
