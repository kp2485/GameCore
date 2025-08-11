//
//  MovementTrapTriggerTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//


import Testing
@testable import GameMap
@testable import GameCore

@Suite struct MovementTrapTriggerTests {

    @Test
    func steppingOntoArmedTrapFires() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        // Trap is on the destination tile (1,0), armed and one-shot.
        map[GridCoord(1,0)].feature = .trap(
            id: "spike",
            detectDC: 60, disarmDC: 60,
            damage: 9,
            once: true,
            armed: true
        )

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)

        var rng: any Randomizer = SeededPRNG(seed: 999)
        let result = rt.moveForward(rng: &rng) // no resolver; no searching first

        #expect(result.moved)
        #expect(result.position == GridCoord(1,0))
        #expect(result.trapDamage == 9)                   // trap fired
        #expect(rt.map[GridCoord(1,0)].feature == .none) // once=true → cleared
    }

    @Test
    func disarmingViaInteractPreventsMovementTrap() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .trap(
            id: "spike",
            detectDC: 40, disarmDC: 40,
            damage: 7,
            once: true,
            armed: true
        )

        // Skilled party can detect+disarm
        let cat = BuiltInSkills.demoCatalog()
        var sheet = SkillSheet()
        sheet.addRanks(BuiltInSkills.perception, 90, using: cat)
        sheet.addRanks(BuiltInSkills.disarm, 90, using: cat)

        struct Resolver: SkillResolver {
            let sheet: SkillSheet; let cat: SkillCatalog
            func check(id: SkillID, dc: Int, rng: inout any Randomizer) -> SkillOutcome {
                SkillSystem.check(id: id, sheet: sheet, catalog: cat, dc: dc, rng: &rng)
            }
        }

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 1)

        // Interact ahead first → disarm
        let out = rt.interactAhead(resolver: Resolver(sheet: sheet, cat: cat), rng: &rng)
        #expect(out == .trapDisarmed)

        // Now step onto tile → no trapDamage
        let res2 = rt.moveForward(rng: &rng)
        #expect(res2.trapDamage == nil)
        #expect(rt.map[GridCoord(1,0)].feature == .none)
    }
}