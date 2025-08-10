//
//  ControllerTargetingTests.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation
import Testing
@testable import GameCore

private func char(_ name: String, _ stats: [CoreStat: Int], tags: Set<String> = []) -> Character {
    Character(name: name, stats: StatBlock(stats), tags: tags)
}

@Suite struct ControllerTargetingTests {

    @Test func lowestHPEnemyIsSelected() {
        let hero = char("Hero", [.str: 8, .spd: 6, .vit: 6])
        let gob1 = char("Gob1", [.spd: 5, .vit: 4]) // hp 12 in encounter
        let gob2 = char("Gob2", [.spd: 5, .vit: 4]) // hp 3 in encounter (lowest)

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 25)],
            foes:   [Combatant(base: gob1, hp: 12), Combatant(base: gob2, hp: 3)]
        )

        let rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )

        var rng: any Randomizer = SeededPRNG(seed: 2)
        let sel = ControllerTargeting.resolve(rule: .lowestHPEnemy, in: rt, rng: &rng)
        #expect(sel.first?.name == "Gob2")
    }

    @Test func randomEnemyIsDeterministicWithSeed() {
        let hero = char("Hero", [.str: 8, .spd: 6, .vit: 6])
        let g1 = char("G1", [.spd: 5]); let g2 = char("G2", [.spd: 5]); let g3 = char("G3", [.spd: 5])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 20)],
            foes:   [Combatant(base: g1, hp: 10), Combatant(base: g2, hp: 10), Combatant(base: g3, hp: 10)]
        )
        let rt = CombatRuntime<Character>(tick: 0, encounter: enc, currentIndex: 0, side: .allies, rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:])

        var r1: any Randomizer = SeededPRNG(seed: 999)
        var r2: any Randomizer = SeededPRNG(seed: 999)
        let a = ControllerTargeting.resolve(rule: .randomEnemy, in: rt, rng: &r1).first?.name
        let b = ControllerTargeting.resolve(rule: .randomEnemy, in: rt, rng: &r2).first?.name
        #expect(a == b)
    }

    @Test func simpleAITargetsByRuleAndDealsDamage() {
        let hero = char("Hero", [.str: 8, .spd: 6, .vit: 6])
        let mage = char("Magey", [.spd: 5, .vit: 4], tags: ["class:mage"])
        let grunt = char("Grunt", [.spd: 5, .vit: 8])

        let enc = Encounter(
            allies: [Combatant(base: hero,  hp: 28)],
            foes:   [Combatant(base: mage,  hp: 6),  // squishy caster
                     Combatant(base: grunt, hp: 18)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )

        var r: any Randomizer = SeededPRNG(seed: 10)
        let ai = SimpleAI(rule: .enemyWithTag("class:mage"))
        let plan = ai.plan(in: rt, rng: &r)!
        let before = rt.hp(of: mage)!
        let ev = plan.exec(&rt, &r)
        let after = rt.hp(of: mage)!

        #expect(!ev.isEmpty)
        #expect(after <= before)
    }
}
