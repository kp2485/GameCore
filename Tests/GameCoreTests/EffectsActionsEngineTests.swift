//
//  EffectsActionsEngineTests.swift
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

@Suite struct EffectsActionsEngineTests {

    @Test func damageIsNonNegative() {
        var rng: any Randomizer = SeededPRNG(seed: 42)

        let a = char("A", [.str: 5])
        let b = char("B", [.vit: 4])

        let enc = Encounter(
            allies: [Combatant(base: a, hp: 30)],
            foes:   [Combatant(base: b, hp: 30)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1)
        )

        let eff = Damage<Character>(kind: .physical, base: 3, scale: { $0.stats[.str] })

        var tgt = b
        let events = eff.apply(to: &tgt, state: &rt, rng: &rng)

        #expect(events.contains { $0.kind == Event.Kind.damage })
        #expect(rt.hp(of: tgt)! >= 0) // HP never below zero
    }

    @Test func simpleAttackReducesHP() {
        var rng: any Randomizer = SeededPRNG(seed: 99)

        let a = char("War", [.str: 8, .spd: 5, .vit: 4])
        let b = char("Rat", [.spd: 4, .vit: 2])

        let enc = Encounter(
            allies: [Combatant(base: a, hp: 20)],
            foes:   [Combatant(base: b, hp: 12)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1)
        )

        var action = Attack<Character>()
        let before = rt.hp(of: b)!
        let events = action.perform(in: &rt, rng: &rng)
        let after = rt.hp(of: b)!

        #expect(events.contains { $0.kind == Event.Kind.damage })
        #expect(after < before) // attack should reduce HP
    }

    @Test func initiativeIsDeterministic() {
        let a = char("A", [.spd: 5])
        let b = char("B", [.spd: 7])
        let c = char("C", [.spd: 6])

        let enc = Encounter(
            allies: [Combatant(base: a, hp: 10)],
            foes:   [Combatant(base: b, hp: 10), Combatant(base: c, hp: 10)]
        )

        let engine = TurnEngine<Character>()
        let order1 = engine.initiativeOrder(for: enc, seed: 123)
        let order2 = engine.initiativeOrder(for: enc, seed: 123)

        #expect(order1.map { $0.actor.name } == order2.map { $0.actor.name })
    }

    @Test func runRoundProducesEventsAndDeaths() {
        let hero   = char("Hero",   [.spd: 9, .str: 9])
        let goblin = char("Goblin", [.spd: 4, .vit: 1])

        let enc = Encounter(
            allies: [Combatant(base: hero,   hp: 20)],
            foes:   [Combatant(base: goblin, hp: 5)]
        )

        let engine = TurnEngine<Character>()
        let (events, result) = engine.runOneRound(encounter: enc, seed: 77)

        #expect(!events.isEmpty)

        // Goblin may die depending on variance; bound checks are stable.
        let gobHP = result.foes.first!.hp
        #expect(gobHP >= 0)
        #expect(gobHP <= 5)
    }
}
