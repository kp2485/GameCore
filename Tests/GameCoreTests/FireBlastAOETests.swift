//
//  FireBlastAOETests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

private func C(_ name: String, _ stats: [CoreStat: Int], tags: Set<String> = []) -> Character {
    Character(name: name, stats: StatBlock(stats), tags: tags)
}

@Suite struct FireBlastAOETests {

    @Test
    func hitsAllFoes_andSpendsMPOnce() {
        let mage  = C("Mage", [.hp: 24, .mp: 20, .int: 16])
        let g1    = C("Gob A", [.hp: 18])
        let g2    = C("Gob B", [.hp: 18])

        let enc = Encounter(
            allies: [Combatant(base: mage, hp: mage.stats[.hp])],
            foes:   [Combatant(base: g1,   hp: g1.stats[.hp]),
                     Combatant(base: g2,   hp: g2.stats[.hp])]
        )

        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )
        // seed MP
        rt.setMP(of: mage, to: mage.stats[.mp])

        var rng: any Randomizer = SeededPRNG(seed: 9)
        var action = CastAllFoes<Character, FireBlast<Character>>()

        let mpBefore = rt.mp(of: mage)
        let hpBefore = rt.encounter.foes.map { $0.hp }

        let ev = action.perform(in: &rt, rng: &rng)

        // Should damage both targets
        let hpAfter = rt.encounter.foes.map { $0.hp }
        #expect(hpAfter[0] < hpBefore[0])
        #expect(hpAfter[1] < hpBefore[1])

        // MP should go down exactly once by the spell's cost
        let cost = FireBlast<Character>.mpCost(for: mage)
        #expect(rt.mp(of: mage) == mpBefore - cost)

        // Should log an action with aoe marker
        #expect(ev.contains { if case .action = $0.kind, $0.data["aoe"] == "allFoes" { true } else { false } })
    }

    @Test
    func respectsElementalResistance_onEachTarget() {
        let mage  = C("Mage", [.hp: 24, .mp: 20, .int: 18])
        let g1    = C("Gob A", [.hp: 20], tags: [])                     // no resist
        let g2    = C("Gob B", [.hp: 20], tags: ["resist:fire=50"])     // 50% fire resist

        let enc = Encounter(
            allies: [Combatant(base: mage, hp: mage.stats[.hp])],
            foes:   [Combatant(base: g1,   hp: g1.stats[.hp]),
                     Combatant(base: g2,   hp: g2.stats[.hp])]
        )

        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )
        rt.setMP(of: mage, to: mage.stats[.mp])

        // Zero variance for a stable expectation
        var rng: any Randomizer = SeededPRNG(seed: 0)
        var action = CastAllFoes<Character, FireBlast<Character>>()

        let before1 = rt.hp(of: g1)!
        let before2 = rt.hp(of: g2)!
        _ = action.perform(in: &rt, rng: &rng)
        let after1  = rt.hp(of: g1)!
        let after2  = rt.hp(of: g2)!

        let dmg1 = before1 - after1
        let dmg2 = before2 - after2

        #expect(dmg2 <= dmg1) // resistant target should not take more damage
    }
}
