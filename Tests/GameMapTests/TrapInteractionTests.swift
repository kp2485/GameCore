//
//  TrapInteractionTests.swift
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

@Suite struct TrapInteractionTests {

    @Test
    func detectAndDisarmTrap() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .trap(id: "spike",
                                             detectDC: 50, disarmDC: 50,
                                             damage: 12, once: true, armed: true)

        let cat = BuiltInSkills.demoCatalog()
        var sheet = SkillSheet()

        // Guarantee success regardless of RNG: totals comfortably over DCs.
        sheet.addRanks(BuiltInSkills.perception, 100, using: cat)
        sheet.setBonus(BuiltInSkills.perception, 30)   // total 130 → target clamps to 100
        sheet.addRanks(BuiltInSkills.disarm, 100, using: cat)
        sheet.setBonus(BuiltInSkills.disarm, 30)       // total 130 → target clamps to 100

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 1)   // seed irrelevant now
        let out = rt.interactAhead(resolver: SheetResolver(sheet: sheet, catalog: cat), rng: &rng)

        #expect(out == .trapDisarmed)
        #expect(rt.map[GridCoord(1,0)].feature == .none)
    }

    @Test
    func failDisarmTriggersTrap() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .trap(id: "spike", detectDC: 30, disarmDC: 90, damage: 9, once: true, armed: true)

        let cat = BuiltInSkills.demoCatalog()
        var sheet = SkillSheet()
        sheet.addRanks(BuiltInSkills.perception, 80, using: cat) // detect ok
        sheet.addRanks(BuiltInSkills.disarm, 10, using: cat)     // disarm bad

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 7)
        let out = rt.interactAhead(resolver: SheetResolver(sheet: sheet, catalog: cat), rng: &rng)
        switch out {
        case .trapTriggered(damage: let dmg): #expect(dmg == 9)
        default: #expect(Bool(false), "Expected trapTriggered")
        }
        #expect(rt.map[GridCoord(1,0)].feature == .none) // once=true cleared
    }
}
