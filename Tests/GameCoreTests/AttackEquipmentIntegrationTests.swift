//
//  AttackEquipmentIntegrationTests.swift
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

@Suite struct AttackEquipmentIntegrationTests {

    @Test func attackWithoutEquipmentStillDealsDamage() {
        // Hero STR=7, Goblin 20 HP
        let hero = char("Hero", [.str: 7, .spd: 6, .vit: 5])
        let gob  = char("Gob",  [.spd: 4, .vit: 3])

        let enc = Encounter(allies: [Combatant(base: hero, hp: 30)],
                            foes:   [Combatant(base: gob,  hp: 20)])

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

        var rng: any Randomizer = SeededPRNG(seed: 10)
        var attack = Attack<Character>()
        let before = rt.hp(of: gob)!
        let ev = attack.performWithEquipment(in: &rt, rng: &rng)
        let after = rt.hp(of: gob)!

        #expect(!ev.isEmpty)
        #expect(after < before) // some damage happened
    }

    @Test func weaponIncreasesDamage() {
        let hero = char("Hero", [.str: 7, .spd: 6, .vit: 5])
        let gob  = char("Gob",  [.spd: 4, .vit: 3])

        let enc = Encounter(allies: [Combatant(base: hero, hp: 30)],
                            foes:   [Combatant(base: gob,  hp: 20)])

        // Two identical runtimes; in the second, equip a sword to the hero
        var rtNoWeapon = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        var rtWithWeapon = rtNoWeapon

        let sword = Weapon(id: "sw1", name: "Shortsword", tags: ["blade"], baseDamage: 4, scale: { $0.stats[.str] / 2 })
        rtWithWeapon.equipment[hero.id] = Equipment(bySlot: [.mainHand: sword])

        // Use the same RNG seed for fairness
        var rng1: any Randomizer = SeededPRNG(seed: 99)
        var rng2: any Randomizer = SeededPRNG(seed: 99)

        // Attack both ways
        var attack1 = Attack<Character>()
        var attack2 = Attack<Character>()

        let before1 = rtNoWeapon.hp(of: gob)!
        _ = attack1.performWithEquipment(in: &rtNoWeapon, rng: &rng1)
        let after1 = rtNoWeapon.hp(of: gob)!
        let dmgNoWeapon = before1 - after1

        let before2 = rtWithWeapon.hp(of: gob)!
        _ = attack2.performWithEquipment(in: &rtWithWeapon, rng: &rng2)
        let after2 = rtWithWeapon.hp(of: gob)!
        let dmgWithWeapon = before2 - after2

        #expect(dmgWithWeapon >= dmgNoWeapon) // weapon should not reduce damage; usually increases it
    }

    @Test func armorMitigatesDamage() {
        let hero = char("Hero", [.str: 7, .spd: 6, .vit: 5])
        let gob  = char("Gob",  [.spd: 4, .vit: 3])

        let enc = Encounter(allies: [Combatant(base: hero, hp: 30)],
                            foes:   [Combatant(base: gob,  hp: 20)])

        // Two identical runtimes; in the second, put a cap (10% mitigation) on goblin
        var rtNoArmor = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        var rtWithArmor = rtNoArmor

        let cap = Armor(id: "cap", name: "Leather Cap", tags: ["light"], mitigationPercent: 10)
        rtWithArmor.equipment[gob.id] = Equipment(bySlot: [.head: cap])

        // Same RNGs for fairness
        var rng1: any Randomizer = SeededPRNG(seed: 77)
        var rng2: any Randomizer = SeededPRNG(seed: 77)

        var attack1 = Attack<Character>()
        var attack2 = Attack<Character>()

        let before1 = rtNoArmor.hp(of: gob)!
        _ = attack1.performWithEquipment(in: &rtNoArmor, rng: &rng1)
        let after1 = rtNoArmor.hp(of: gob)!
        let dmgNoArmor = before1 - after1

        let before2 = rtWithArmor.hp(of: gob)!
        _ = attack2.performWithEquipment(in: &rtWithArmor, rng: &rng2)
        let after2 = rtWithArmor.hp(of: gob)!
        let dmgWithArmor = before2 - after2

        #expect(dmgWithArmor <= dmgNoArmor) // armor should not increase damage
    }

    @Test func weaponAndArmorTogetherBehaveSensibly() {
        let hero = char("Hero", [.str: 9, .spd: 6, .vit: 6])
        let gob  = char("Gob",  [.spd: 4, .vit: 3])

        let enc = Encounter(allies: [Combatant(base: hero, hp: 30)],
                            foes:   [Combatant(base: gob,  hp: 22)])

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

        let sword = Weapon(id: "sw", name: "Sword", tags: ["blade"], baseDamage: 5, scale: { $0.stats[.str] / 3 })
        let helm  = Armor(id: "helm", name: "Bronze Helm", tags: ["light"], mitigationPercent: 15)
        rt.equipment[hero.id] = Equipment(bySlot: [.mainHand: sword])
        rt.equipment[gob.id]  = Equipment(bySlot: [.head: helm])

        var rng: any Randomizer = SeededPRNG(seed: 101)
        var attack = Attack<Character>()
        let before = rt.hp(of: gob)!
        _ = attack.performWithEquipment(in: &rt, rng: &rng)
        let after = rt.hp(of: gob)!

        let dmg = before - after
        #expect(dmg > 0)
        #expect(dmg <= 30) // sanity upper bound given stats & mitigation
    }
}
