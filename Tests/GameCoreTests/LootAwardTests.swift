//
//  LootAwardTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

private func C(_ n: String, _ s: [CoreStat:Int]) -> Character { Character(name: n, stats: StatBlock(s)) }

@Suite struct LootAwardTests {

    @Test
    func victoryAwardsGoldAndLoot() {
        let hero = C("Hero", [.hp: 30, .str: 12, .spd: 14])
        let f1   = C("Slime A", [.hp: 8, .spd: 2])
        let f2   = C("Slime B", [.hp: 8, .spd: 2])

        // Deterministic loot: two pulls from { herb(3), gem(1) }
        let bundle = LootBundle(pulls: 2, entries: [
            LootEntry(itemId: "herb", minQty: 1, maxQty: 1, weight: 3),
            LootEntry(itemId: "gem",  minQty: 1, maxQty: 1, weight: 1),
        ])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [
                Combatant(base: f1, hp: 8, xpValue: 150, goldValue: 20, loot: bundle),
                Combatant(base: f2, hp: 8, xpValue: 150, goldValue: 30, loot: bundle)
            ]
        )

        // Allies attack; foes idle.
        let engine = TurnEngine<Character>()
        let allyAI: [any Controller<Character>] = [SimpleAI()]
        let foeAI:  [any Controller<Character>] = [IdleController(), IdleController()]

        let (events, result, outcome) = engine.runUntilVictory(
            encounter: enc,
            allyControllers: allyAI,
            foeControllers: foeAI,
            seed: 42,
            maxRounds: 10
        )

        #expect(outcome == .alliesWin)
        #expect(result.foes.allSatisfy { $0.hp == 0 })

        // Gold aggregated = 50
        let gold = events.compactMap { $0.kind == .goldAwarded ? Int($0.data["amount"] ?? "") : nil }.reduce(0, +)
        #expect(gold == 50)

        // At least one lootDropped event (deterministic with seed 42)
        let hasLoot = events.contains { $0.kind == .lootDropped }
        #expect(hasLoot)

        // XP events should exist as well (from earlier wiring)
        let hasXP = events.contains { $0.kind == .xpGained }
        #expect(hasXP)
    }
}
