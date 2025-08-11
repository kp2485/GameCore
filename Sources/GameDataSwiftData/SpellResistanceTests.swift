//
//  SpellResistanceTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct SpellResistanceTests {

    private func mage() -> Character {
        Character(name: "Mage", stats: StatBlock([.hp: 24, .mp: 20, .int: 16, .vit: 6]))
    }

    @Test
    func fireBolt_unresisted_deals_full_damage() throws {
        var rng: any Randomizer = SeededPRNG(seed: 123)
        var caster = mage()
        var target = Character(name: "Dummy", stats: StatBlock([.hp: 40, .vit: 5])) // no resist tags
        let book = Spellbook([BuiltInSpells.fireBolt])

        let hpBefore = target.stats[.hp]
        let _ = try SpellSystem.cast(FireBolt<Character>.self, caster: &caster, target: &target, book: book, rng: &rng)
        #expect(target.stats[.hp] < hpBefore)
    }

    @Test
    func fireBolt_resisted_is_reduced() throws {
        var rng: any Randomizer = SeededPRNG(seed: 123) // same seed as above → same raw roll
        var caster = mage()
        var resisted = Character(name: "Resist Dummy",
                                 stats: StatBlock([.hp: 40, .vit: 5]),
                                 tags: ["resist:fire=50"]) // 50% resist

        let book = Spellbook([BuiltInSpells.fireBolt])

        // First: compute baseline damage by casting on an unresisted dummy with the same seed.
        var targetBaseline = Character(name: "Baseline", stats: StatBlock([.hp: 40]))
        var rngBaseline: any Randomizer = SeededPRNG(seed: 123)
        var casterCopy = caster
        let hpBeforeBase = targetBaseline.stats[.hp]
        let _ = try SpellSystem.cast(FireBolt<Character>.self, caster: &casterCopy, target: &targetBaseline, book: book, rng: &rngBaseline)
        let baselineDamage = hpBeforeBase - targetBaseline.stats[.hp]
        #expect(baselineDamage > 0)

        // Now resisted target with identical RNG path
        let hpBeforeRes = resisted.stats[.hp]
        let _ = try SpellSystem.cast(FireBolt<Character>.self, caster: &caster, target: &resisted, book: book, rng: &rng)
        let resistedDamage = hpBeforeRes - resisted.stats[.hp]

        // Should be roughly half (integer division exact: floor(raw * 0.5))
        #expect(resistedDamage == baselineDamage / 2)
    }

    @Test
    func fireBolt_100pct_resist_deals_zero() throws {
        var rng: any Randomizer = SeededPRNG(seed: 99)
        var caster = mage()
        var target = Character(name: "Immune", stats: StatBlock([.hp: 40]), tags: ["resist:fire=100"])
        let book = Spellbook([BuiltInSpells.fireBolt])

        let hpBefore = target.stats[.hp]
        let _ = try SpellSystem.cast(FireBolt<Character>.self, caster: &caster, target: &target, book: book, rng: &rng)
        #expect(target.stats[.hp] == hpBefore) // no damage
    }
}
