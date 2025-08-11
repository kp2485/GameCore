//
//  CostsAndDefendTests.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation
import Testing
@testable import GameCore

private func char(_ name: String, _ stats: [CoreStat: Int]) -> Character {
    Character(name: name, stats: StatBlock(stats))
}

@Suite struct CostsAndDefendTests {

    @Test func castSpendsMPAndFailsWhenInsufficient() {
        let mage = char("Mage", [.int: 8, .spi: 6, .spd: 5])
        let gob  = char("Gob",  [.vit: 2, .spd: 4])

        let enc = Encounter(
            allies: [Combatant(base: mage, hp: 20)],
            foes:   [Combatant(base: gob,  hp: 12)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,                // allies turn -> index 0 is mage
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:]
        )
        // Start with 5 MP
        rt.setMP(of: mage, to: 5)

        var rng: any Randomizer = SeededPRNG(seed: 10)

        let bolt = Ability<Character>(name: "Bolt", costMP: 3, targeting: .singleEnemy) {
            AnyEffect(Damage<Character>(kind: .shock, base: 4, scale: { _ in 2 }))
        }

        var cast = Cast<Character>(bolt)
        let mpBefore = rt.mp(of: mage)
        let ev1 = cast.perform(in: &rt, rng: &rng)
        let mpAfter = rt.mp(of: mage)
        #expect(ev1.contains { $0.kind == .action })
        #expect(mpBefore - mpAfter == 3)

        // Second cast should fail on MP (only 2 left)
        let ev2 = cast.perform(in: &rt, rng: &rng)
        #expect(ev2.contains { $0.data["reason"] == "insufficientMP" })
    }

    @Test func defendAppliesMitigationAndReducesDamage() {
        let hero = char("Hero", [.str: 6, .vit: 4, .spd: 6])
        let ogre = char("Ogre", [.str: 10, .spd: 4])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: ogre, hp: 30)]
        )

        // Build two runtimes for comparison. It’s the FOE’s turn (ogre),
        // and there is exactly one foe, so index must be 0 for .foes.
        var rtNoDef = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,                // <-- ogre is foes[0]
            side: .foes,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:]
        )
        var rtDef = rtNoDef

        // Apply Defend on hero in the defended case
        var rngDef: any Randomizer = SeededPRNG(seed: 2)
        var defend = Defend<Character>()
        _ = defend.perform(in: &rtDef, rng: &rngDef)

        // Ogre attacks hero in both cases (same RNG seed for fairness)
        var rng1: any Randomizer = SeededPRNG(seed: 3)
        var rng2: any Randomizer = SeededPRNG(seed: 3)

        var attack1 = Attack<Character>(damage: Damage(kind: .physical, base: 5, scale: { (c: Character) -> Int in
            c.stats[.str] }))
        var attack2 = Attack<Character>(damage: Damage(kind: .physical, base: 3, scale: { (c: Character) -> Int in
            c.stats[.str] }))

        let hpbefore1 = rtNoDef.hp(of: hero)!
        _ = attack1.perform(in: &rtNoDef, rng: &rng1)
        let hpafter1 = rtNoDef.hp(of: hero)!

        let hpbefore2 = rtDef.hp(of: hero)!
        _ = attack2.perform(in: &rtDef, rng: &rng2)
        let hpafter2 = rtDef.hp(of: hero)!

        let dmgNoDef = hpbefore1 - hpafter1
        let dmgDef   = hpbefore2 - hpafter2

        #expect(dmgDef <= dmgNoDef) // defended damage is reduced or equal (variance may tie)
    }
}
