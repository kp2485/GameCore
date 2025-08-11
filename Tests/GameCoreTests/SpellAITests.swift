//
//  SpellAITests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation
import Testing
@testable import GameCore

@Suite struct SpellAITests {

    private func makeC(
        _ name: String,
        _ hp: Int,
        _ mp: Int,
        extra: [CoreStat: Int] = [:],
        tags: Set<String> = []
    ) -> Character {
        var stats: StatBlock<CoreStat> = StatBlock<CoreStat>([.hp: hp, .mp: mp, .int: 14, .vit: 8])
        for (k, v) in extra { stats[k] = v }
        return Character(name: name, stats: stats, tags: tags)
    }

    private func combatants(_ chars: [Character]) -> [Combatant<Character>] {
        chars.map { Combatant(base: $0, hp: $0.stats[.hp]) }
    }

    @Test
    func healerPicksAllyAndHeals_whenBelowThreshold() {
        // Ally party: Healer + Wounded
        let healer  = makeC("Cleric", 18, 12, extra: [.vit: 10])
        let wounded = makeC("Fighter", 30, 0)
        // Start wounded at low HP in the encounter
        let woundedStartHP = 7
        var allies = combatants([healer, wounded])
        allies[1].hp = woundedStartHP

        // One foe just to keep fight context consistent
        let foe = makeC("Goblin", 20, 0)
        let enc = Encounter(allies: allies, foes: combatants([foe]))

        // Spellbook: healer knows HealWounds
        let books: [UUID: Spellbook] = [healer.id: Spellbook([BuiltInSpells.healWounds])]

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0, // healer's turn
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        // Ensure runtime has MP set (uses default if absent, but let's be explicit)
        rt.setMP(of: healer, to: healer.stats[.mp])

        var rng: any Randomizer = SeededPRNG(seed: 2)
        let ai = SpellAI(spellbooksById: books, healThresholdPercent: 50)

        guard let plan = ai.plan(in: rt, rng: &rng) else {
            #expect(Bool(false), "Expected a heal plan")
            return
        }
        let events = plan.exec(&rt, &rng)

        // Confirm a heal event occurred and HP increased
        #expect(events.contains { if case .heal = $0.kind { true } else { false } })
        #expect(rt.encounter.allies[1].hp > woundedStartHP)
    }

    @Test
    func casterBlastsFoe_whenNoOneNeedsHeal() {
        let mage = makeC("Mage", 20, 12, extra: [.int: 16])
        let ally = makeC("Fighter", 28, 0)
        let foe  = makeC("Imp", 22, 0)

        let enc = Encounter(allies: combatants([mage, ally]),
                            foes:   combatants([foe]))

        let books: [UUID: Spellbook] = [mage.id: Spellbook([BuiltInSpells.fireBolt])]

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0, // mage's turn
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 3),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        rt.setMP(of: mage, to: mage.stats[.mp])

        var rng: any Randomizer = SeededPRNG(seed: 7)
        let ai = SpellAI(spellbooksById: books, healThresholdPercent: 30)

        guard let plan = ai.plan(in: rt, rng: &rng) else {
            #expect(Bool(false), "Expected a fire bolt plan")
            return
        }
        let foeHP0 = rt.encounter.foes[0].hp
        let events = plan.exec(&rt, &rng)

        #expect(events.contains { if case .damage = $0.kind { true } else { false } })
        #expect(rt.encounter.foes[0].hp < foeHP0)
    }

    @Test
    func runUntilVictory_withSpellAI_vs_SimpleAI() {
        // Allies: Mage (fire bolt), Fighter
        let mage    = makeC("Mage", 22, 12, extra: [.int: 16])
        let fighter = makeC("Fighter", 28, 0, extra: [.str: 12])

        // Foes: two goblins
        let gob1 = makeC("Goblin A", 18, 0)
        let gob2 = makeC("Goblin B", 18, 0)

        let enc = Encounter(allies: combatants([mage, fighter]),
                            foes:   combatants([gob1, gob2]))

        let books: [UUID: Spellbook] = [mage.id: Spellbook([BuiltInSpells.fireBolt])]
        let spellAI = SpellAI(spellbooksById: books, healThresholdPercent: 40)

        // Foes use SimpleAI (physical attacks)
        let simple = SimpleAI()

        let engine = TurnEngine<Character>()
        let (ev, result, outcome) = engine.runUntilVictory(
            encounter: enc,
            allyControllers: [spellAI, simple],  // mage then fighter
            foeControllers: [simple, simple],
            seed: 42,
            maxRounds: 10
        )

        #expect(ev.contains { if case .damage = $0.kind { true } else { false } })
        #expect(outcome == .alliesWin || outcome == .foesWin || outcome == .stalemate)
        #expect(result.allies.count == 2 && result.foes.count == 2)
    }
}
