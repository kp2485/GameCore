//
//  BattleXPTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

private func C(_ n: String, _ s: [CoreStat:Int]) -> Character { Character(name: n, stats: StatBlock(s)) }

/// Controller that does nothing (foes stand still)
struct IdleController: Controller {
    typealias A = Character
    func plan(in state: CombatRuntime<Character>, rng: inout any Randomizer) -> ActionPlan<Character>? { nil }
}

@Suite struct BattleXPTests {

    @Test
    func alliesReceiveXPOnVictory() {
        // Two allies, two weak foes that grant XP when defeated.
        let a1 = C("Hero", [.hp: 30, .str: 10, .spd: 12])
        let a2 = C("Rogue", [.hp: 24, .str: 8, .spd: 14])
        let f1 = C("Slime A", [.hp: 6, .spd: 2])
        let f2 = C("Slime B", [.hp: 6, .spd: 2])

        let enc = Encounter(
            allies: [Combatant(base: a1, hp: 30),
                     Combatant(base: a2, hp: 24)],
            foes:   [Combatant(base: f1, hp: 6, xpValue: 500),
                     Combatant(base: f2, hp: 6, xpValue: 500)]
        )

        // Allies attack using SimpleAI; foes idle.
        let engine = TurnEngine<Character>()
        let allyAI: [any Controller<Character>] = [SimpleAI(), SimpleAI()]
        let foeAI:  [any Controller<Character>] = [IdleController(), IdleController()]

        let (events, result, outcome) = engine.runUntilVictory(
            encounter: enc,
            allyControllers: allyAI,
            foeControllers: foeAI,
            seed: 123,
            maxRounds: 10
        )

        #expect(outcome == .alliesWin)
        // Expect xpGained events for both allies (living at victory).
        let xpForHero  = events.contains { $0.kind == .xpGained && $0.data["actor"] == "Hero" }
        let xpForRogue = events.contains { $0.kind == .xpGained && $0.data["actor"] == "Rogue" }
        #expect(xpForHero && xpForRogue)

        // Given 1000 total XP and 2 living allies -> 500 each.
        // Our default curve levels from 1 -> 3 with 500 XP (200 + 300).
        let heroLeveled = events.contains { $0.kind == .levelUp && $0.data["actor"] == "Hero" }
        let rogueLeveled = events.contains { $0.kind == .levelUp && $0.data["actor"] == "Rogue" }
        #expect(heroLeveled && rogueLeveled)

        // Sanity: foes are dead at the end.
        #expect(result.foes.allSatisfy { $0.hp == 0 })
    }
}
