//
//  SpellTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct SpellTests {

    @Test
    func fireBoltConsumesMPAndDealsDamage() throws {
        var rng: any Randomizer = SeededPRNG(seed: 123)

        // Caster with decent INT and MP
        var caster = Character(name: "Mage", stats: StatBlock([.hp: 24, .mp: 15, .int: 14, .vit: 6]))
        var target = Character(name: "Goblin", stats: StatBlock([.hp: 30, .mp: 0, .vit: 5]))

        let book = Spellbook([BuiltInSpells.fireBolt])

        let beforeMP = caster.stats[.mp]
        let beforeHP = target.stats[.hp]

        let events = try SpellSystem.cast(FireBolt<Character>.self, caster: &caster, target: &target, book: book, rng: &rng)

        // MP spent
        #expect(caster.stats[.mp] == beforeMP - 5)

        // HP reduced by a modest amount (seeded jitter)
        #expect(target.stats[.hp] < beforeHP)
        #expect(events.contains { $0.kind == .damage })
    }

    @Test
    func healWoundsConsumesMPAndHeals() throws {
        var rng: any Randomizer = SeededPRNG(seed: 42)

        var cleric = Character(name: "Cleric", stats: StatBlock([.hp: 12, .mp: 10, .vit: 9]))
        var ally   = Character(name: "Fighter", stats: StatBlock([.hp: 18, .mp: 0, .vit: 8]))

        let book = Spellbook([BuiltInSpells.healWounds])

        let beforeMP = cleric.stats[.mp]
        let beforeHP = ally.stats[.hp]

        let events = try SpellSystem.cast(HealWounds<Character>.self, caster: &cleric, target: &ally, book: book, rng: &rng)

        #expect(cleric.stats[.mp] == beforeMP - 4)
        #expect(ally.stats[.hp] > beforeHP)
        #expect(events.contains { $0.kind == .heal })
    }

    @Test
    func cannotCastIfSpellUnknown() {
        var rng: any Randomizer = SeededPRNG(seed: 1)
        var mage = Character(name: "Mage", stats: StatBlock([.hp: 10, .mp: 10, .int: 10]))
        var foe  = Character(name: "Rat", stats: StatBlock([.hp: 8]))

        let book = Spellbook([]) // knows nothing

        do {
            _ = try SpellSystem.cast(FireBolt<Character>.self, caster: &mage, target: &foe, book: book, rng: &rng)
            #expect(Bool(false), "Should have thrown notKnown")
        } catch let e as SpellError {
            #expect(e == .notKnown)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test
    func cannotCastIfInsufficientMP() {
        var rng: any Randomizer = SeededPRNG(seed: 2)
        var mage = Character(name: "Mage", stats: StatBlock([.hp: 10, .mp: 0, .int: 12]))
        var foe  = Character(name: "Slime", stats: StatBlock([.hp: 20]))

        let book = Spellbook([BuiltInSpells.fireBolt])

        do {
            _ = try SpellSystem.cast(FireBolt<Character>.self, caster: &mage, target: &foe, book: book, rng: &rng)
            #expect(Bool(false), "Should have thrown insufficientMP")
        } catch let .insufficientMP(required: req, available: have) as SpellError {
            #expect(req == 5)
            #expect(have == 0)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}
