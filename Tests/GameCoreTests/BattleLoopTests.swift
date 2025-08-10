//
//  BattleLoopTests.swift
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

@Suite struct BattleLoopTests {

    @Test func heroBeatsGoblinWithSword() {
        // Setup
        let hero = char("Hero", [.str: 9, .spd: 7, .vit: 7])
        let gob  = char("Gob",  [.spd: 5, .vit: 3])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: gob,  hp: 18)]
        )

        // Load equipment
        let sword = Weapon(id: "sw", name: "Sword", tags: ["blade"], baseDamage: 5, scale: { $0.stats[.str] / 2 })
        let heroEq = Equipment(bySlot: [.mainHand: sword])

        // Controllers
        let aiAllies: [SimpleAI] = [SimpleAI(equipmentById: [hero.id: heroEq])]
        let aiFoes:   [SimpleAI] = [SimpleAI()]

        let engine = TurnEngine<Character>()
        let (events, result, outcome) = engine.runUntilVictory(
            encounter: enc,
            allyControllers: aiAllies,
            foeControllers: aiFoes,
            seed: 123,
            maxRounds: 10
        )

        #expect(!events.isEmpty)
        #expect(outcome == .alliesWin)
        #expect(result.foes.first?.hp ?? -1 >= 0)
    }

    @Test func determinismWithSameSeed() {
        let hero = char("Hero", [.str: 8, .spd: 6, .vit: 6])
        let gob  = char("Gob",  [.spd: 5, .vit: 4])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 28)],
            foes:   [Combatant(base: gob,  hp: 20)]
        )

        let aiAllies: [SimpleAI] = [SimpleAI()]
        let aiFoes:   [SimpleAI] = [SimpleAI()]

        let engine = TurnEngine<Character>()

        let (e1, r1, o1) = engine.runUntilVictory(
            encounter: enc, allyControllers: aiAllies, foeControllers: aiFoes, seed: 555, maxRounds: 10
        )
        let (e2, r2, o2) = engine.runUntilVictory(
            encounter: enc, allyControllers: aiAllies, foeControllers: aiFoes, seed: 555, maxRounds: 10
        )

        #expect(o1 == o2)
        #expect(r1.allies.first?.hp == r2.allies.first?.hp)
        #expect(r1.foes.first?.hp == r2.foes.first?.hp)
        #expect(e1.count == e2.count)
    }

    @Test func stalemateTriggersWhenMaxRoundsReached() {
        // Two high-armor tanks who barely damage each other
        let a = char("Tank A", [.str: 5, .spd: 5, .vit: 10])
        let b = char("Tank B", [.str: 5, .spd: 5, .vit: 10])

        let enc = Encounter(
            allies: [Combatant(base: a, hp: 40)],
            foes:   [Combatant(base: b, hp: 40)]
        )

        // Hefty armor both sides (mitigation via equipment)
        let plate = Armor(id: "pl", name: "Plate", tags: ["heavy"], mitigationPercent: 40)
        let eqA = Equipment(bySlot: [.body: plate])
        let eqB = Equipment(bySlot: [.body: plate])

        let aiAllies: [SimpleAI] = [SimpleAI(equipmentById: [a.id: eqA])]
        let aiFoes:   [SimpleAI] = [SimpleAI(equipmentById: [b.id: eqB])]

        let engine = TurnEngine<Character>()
        let (_, _, outcome) = engine.runUntilVictory(
            encounter: enc, allyControllers: aiAllies, foeControllers: aiFoes,
            seed: 42, maxRounds: 1 // force quick stalemate
        )

        #expect(outcome == .stalemate)
    }
}
