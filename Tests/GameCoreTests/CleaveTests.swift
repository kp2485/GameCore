//
//  CleaveTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

private func char(_ name: String, _ stats: [CoreStat: Int]) -> Character {
    Character(name: name, stats: StatBlock(stats))
}

@Suite struct CleaveTests {

    @Test
    func cleaveDamagesAllFoes() {
        let hero = char("Hero", [.str: 8, .vit: 6])
        let g1   = char("Gob A", [.vit: 3])
        let g2   = char("Gob B", [.vit: 3])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: g1, hp: 18), Combatant(base: g2, hp: 18)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )

        var rng: any Randomizer = SeededPRNG(seed: 9)
        var action = Cleave<Character>(base: 4, varianceMax: 0) // deterministic
        let hpBefore = rt.encounter.foes.map { $0.hp }

        let ev = action.perform(in: &rt, rng: &rng)
        let hpAfter = rt.encounter.foes.map { $0.hp }

        #expect(ev.contains { if case .damage = $0.kind, $0.data["aoe"] == "cleave" { true } else { false } })
        #expect(hpAfter[0] < hpBefore[0])
        #expect(hpAfter[1] < hpBefore[1])
    }

    @Test
    func armorMitigatesEachTargetIndependently() {
        let hero = char("Hero", [.str: 10, .vit: 6])
        let g1   = char("Gob A", [.vit: 3])
        let g2   = char("Gob B", [.vit: 3])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: g1, hp: 20), Combatant(base: g2, hp: 20)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )

        // Put armor only on Gob B (10% mitigation)
        let cap = Armor(id: "cap", name: "Cap", tags: ["light"], mitigationPercent: 10)
        rt.equipment[g2.id] = Equipment(bySlot: [.head: cap])

        var rng: any Randomizer = SeededPRNG(seed: 7)
        var action = Cleave<Character>(base: 6, varianceMax: 0)

        let beforeA = rt.hp(of: g1)!
        let beforeB = rt.hp(of: g2)!
        _ = action.perform(in: &rt, rng: &rng)
        let afterA  = rt.hp(of: g1)!
        let afterB  = rt.hp(of: g2)!

        let dmgA = beforeA - afterA
        let dmgB = beforeB - afterB
        #expect(dmgB <= dmgA) // armored target shouldn't take more than unarmored
    }

    @Test
    func cleaveCanKillMultiple() {
        let hero = char("Hero", [.str: 14, .vit: 6])
        let g1   = char("Gob A", [.vit: 3])
        let g2   = char("Gob B", [.vit: 3])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: g1, hp: 8), Combatant(base: g2, hp: 8)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )

        var rng: any Randomizer = SeededPRNG(seed: 11)
        var action = Cleave<Character>(base: 6, varianceMax: 0)

        let ev = action.perform(in: &rt, rng: &rng)

        let deaths = ev.filter { if case .death = $0.kind { true } else { false } }.count
        #expect(deaths >= 1)
    }
}
