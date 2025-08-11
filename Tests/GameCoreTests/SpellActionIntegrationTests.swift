//
//  SpellActionIntegrationTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct SpellActionIntegrationTests {

    // Helper to make a combatant with hp pulled from its stats
    private func makeCombatant(_ c: Character) -> Combatant<Character> {
        let hp = c.stats[.hp]
        return Combatant(base: c, hp: hp)
    }

    // 1v1 encounter (ally caster vs foe target)
    private func oneOnOne() -> Encounter<Character> {
        let caster = Character(name: "Mage",
                               stats: StatBlock([.hp: 24, .mp: 10, .int: 16, .vit: 6]))
        let foe    = Character(name: "Imp",
                               stats: StatBlock([.hp: 20, .mp: 0,  .vit: 5]))
        return Encounter(
            allies: [makeCombatant(caster)],
            foes:   [makeCombatant(foe)]
        )
    }

    @Test
    func legalityAndSelection() {
        let enc = oneOnOne()
        let rt  = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1)
        )

        let action = CastSpell<Character, FireBolt<Character>>(
            FireBolt<Character>.self,
            book: Spellbook([BuiltInSpells.fireBolt])
        )

        #expect(action.legality(in: rt))

        var rng: any Randomizer = SeededPRNG(seed: 1)
        let targets = action.selectTargets(in: rt, rng: &rng)
        #expect(targets.count == 1)
        #expect(targets.first?.name == "Imp")
    }

    @Test
    func performReturnsDamageEvents_whenLegal() {
        var rng: any Randomizer = SeededPRNG(seed: 7)

        let enc = oneOnOne()
        var rt  = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 2)
        )

        var action = CastSpell<Character, FireBolt<Character>>(
            FireBolt<Character>.self,
            book: Spellbook([BuiltInSpells.fireBolt])
        )

        let events = action.perform(in: &rt, rng: &rng)
        #expect(!events.isEmpty)
        #expect(events.contains { if case .damage = $0.kind { true } else { false } })
    }

    @Test
    func legalityBlocksUnknownSpell_andPerformNoops() {
        var rng: any Randomizer = SeededPRNG(seed: 42)

        let enc = oneOnOne()
        var rt  = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 3)
        )

        var action = CastSpell<Character, FireBolt<Character>>(
            FireBolt<Character>.self,
            book: Spellbook([]) // unknown
        )

        #expect(!action.legality(in: rt))

        let events = action.perform(in: &rt, rng: &rng)
        #expect(events.isEmpty)
    }

    @Test
    func healSpellProducesHealEvents() {
        var rng: any Randomizer = SeededPRNG(seed: 13)

        // Cleric (ally) and a wounded foe — verifying event shape.
        let cleric = Character(name: "Cleric",
                               stats: StatBlock([.hp: 18, .mp: 12, .vit: 9]))
        let wounded = Character(name: "Fighter",
                                stats: StatBlock([.hp: 9, .mp: 0, .vit: 7]))

        let enc = Encounter(
            allies: [makeCombatant(cleric)],
            foes:   [makeCombatant(wounded)]
        )
        var rt  = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 5)
        )

        var action = CastSpell<Character, HealWounds<Character>>(
            HealWounds<Character>.self,
            book: Spellbook([BuiltInSpells.healWounds])
        )

        let events = action.perform(in: &rt, rng: &rng)
        #expect(events.contains { if case .heal = $0.kind { true } else { false } })
    }
}
