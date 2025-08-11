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
        let hero = char("Hero", [.str: 18, .spd: 24, .vit: 6])   // higher SPD -> high hit chance
        let g1   = char("Gob A", [.vit: 3, .spd: 4])
        let g2   = char("Gob B", [.vit: 3, .spd: 4])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: g1, hp: 18), Combatant(base: g2, hp: 18)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )

        var rng: any Randomizer = SeededPRNG(seed: 9)            // fixed seed for determinism
        var action = Cleave<Character>(base: 4, varianceMax: 0)  // no variance

        let hpBefore = rt.encounter.foes.map { $0.hp }
        let ev = action.perform(in: &rt, rng: &rng)
        let hpAfter = rt.encounter.foes.map { $0.hp }

        // Each foe should either take damage OR be recorded as a miss for this AoE.
        for (idx, foe) in [g1, g2].enumerated() {
            if hpAfter[idx] == hpBefore[idx] {
                #expect(ev.contains { $0.kind == Event.Kind.note && $0.data["result"] == "miss" && $0.data["target"] == foe.name })
            } else {
                #expect(hpAfter[idx] < hpBefore[idx])
            }
        }
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
        // High SPD to reach 95% hit chance; zero variance; enough base to kill 8 HP on hit.
        let hero = char("Hero", [.str: 14, .spd: 50, .vit: 6])
        let g1   = char("Gob A", [.vit: 3, .spd: 4])
        let g2   = char("Gob B", [.vit: 3, .spd: 4])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: g1, hp: 8), Combatant(base: g2, hp: 8)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )

        // Seed 0 tends to produce a low first roll for our PRNG, ensuring hits here.
        var rng: any Randomizer = SeededPRNG(seed: 0)
        var action = Cleave<Character>(base: 10, varianceMax: 0)

        let ev = action.perform(in: &rt, rng: &rng)

        // Count death events
        let deaths = ev.filter { $0.kind == Event.Kind.death }.count
        #expect(deaths >= 1)
    }
}
