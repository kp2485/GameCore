//
//  CombatMathTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

import Foundation
import Testing
@testable import GameCore

private func char(_ name: String, _ stats: [CoreStat: Int]) -> Character {
    Character(name: name, stats: StatBlock(stats))
}

@Suite
struct CombatMathTests {

    @Test
    func centralMathProducesSaneDamage() {
        var rng: any Randomizer = SeededPRNG(seed: 123)

        let hero = char("Hero", [.str: 8, .vit: 5, .spd: 6])
        let gob  = char("Gob",  [.vit: 3, .spd: 4])

        // No armor/status mitigation, modest weapon, base 5
        let (total, variance, mit) = CombatMath.physicalAttack(
            source: hero,
            target: gob,
            weaponDamage: 3,
            baseBonus: 5,
            statusMitigationPercent: 0,
            armorMitigationPercent: 0,
            rng: &rng,
            rules: .default
        )

        #expect(total > 0)
        #expect(variance >= 0 && variance <= Int(GameRules.default.attackVarianceMax))
        #expect(mit == 0)
    }

    @Test
    func mitigationNeverExceedsConfiguredCap() {
        var rng: any Randomizer = SeededPRNG(seed: 7)
        let hero = char("Hero", [.str: 20])
        let ogre = char("Ogre", [.vit: 10])

        // Over-the-top mitigation inputs
        let rules = GameRules(attackVarianceMax: 0, maxMitigationPercent: 60)
        let (_, _, mit) = CombatMath.physicalAttack(
            source: hero,
            target: ogre,
            weaponDamage: 0,
            baseBonus: 10,
            statusMitigationPercent: 50,
            armorMitigationPercent: 40,
            rng: &rng,
            rules: rules
        )

        #expect(mit <= 60)
    }
}
