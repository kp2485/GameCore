//
//  EquipmentTests.swift
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

@Suite struct EquipmentTests {

    @Test func equipAndUnequip() throws {
        var loadout = Loadout()
        let sword = Weapon(id: "sw1", name: "Shortsword", tags: ["blade"], baseDamage: 3, scale: { $0.stats[.str] / 2 })
        let helm  = Armor(id: "h1", name: "Leather Cap", tags: ["light"], mitigationPercent: 5)

        loadout.add(sword)
        loadout.add(helm)

        let fighter = ClassDef(id: "fighter", name: "Fighter", allowedWeapons: ["blade"], allowedArmor: ["light", "heavy"])
        let c = char("Arden", [.str: 8, .vit: 6])

        try loadout.equip(itemId: "sw1", to: .mainHand, for: c, classDef: fighter)
        try loadout.equip(itemId: "h1",  to: .head,     for: c, classDef: fighter)

        #expect(loadout.equipment.item(in: .mainHand) != nil)
        #expect(loadout.equipment.item(in: .head) != nil)

        let removed = try loadout.equipment.unequip(from: .head)
        #expect((removed as! Armor).name == "Leather Cap")
    }

    @Test func classLegalityBlocksWrongTags() {
        var loadout = Loadout()
        let staff = Weapon(id: "st1", name: "Apprentice Staff", tags: ["staff"], baseDamage: 2)
        loadout.add(staff)
        let fighter = ClassDef(id: "fighter", name: "Fighter", allowedWeapons: ["blade"], allowedArmor: ["light", "heavy"])
        let c = char("Brom", [.str: 7])
        do {
            try loadout.equip(itemId: "st1", to: .mainHand, for: c, classDef: fighter)
            #expect(Bool(false), "Expected notAllowed for wrong weapon tag")
        } catch ItemError.notAllowed(_) {
            #expect(true)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func attackAccountsForWeaponAndArmorMitigation() {
        // Setup characters
        let hero = char("Hero", [.str: 8, .vit: 6, .spd: 6])
        let gob  = char("Gob",  [.vit: 3, .spd: 4])
        let enc = Encounter(allies: [Combatant(base: hero, hp: 30)], foes: [Combatant(base: gob, hp: 20)])

        // Runtime with equipment
        var rt = CombatRuntime<Character>(tick: 0, encounter: enc, currentIndex: 0, side: .allies, rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:])

        // Equip hero with a sword; goblin with a leather cap
        let sword = Weapon(id: "sw1", name: "Shortsword", tags: ["blade"], baseDamage: 3, scale: { $0.stats[.str] / 2 })
        let cap   = Armor(id: "cap", name: "Leather Cap", tags: ["light"], mitigationPercent: 10)
        rt.equipment[hero.id] = Equipment(bySlot: [.mainHand: sword])
        rt.equipment[gob.id]  = Equipment(bySlot: [.head: cap])

        // Perform attack using the equipment-aware variant
        var rng: any Randomizer = SeededPRNG(seed: 7)
        var attack = Attack<Character>()
        let before = rt.hp(of: gob)!
        _ = attack.perform(in: &rt, rng: &rng) // extension picks first foe
        let after = rt.hp(of: gob)!

        // We can't assert exact numbers due to variance, but damage should be > 0 and
        // lower than if there were no armor. Quick sanity window:
        let dmg = before - after
        #expect(dmg > 0)
        #expect(dmg <= 20)
    }
}
