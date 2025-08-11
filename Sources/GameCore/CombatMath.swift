//
//  CombatMath.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

import Foundation

public enum CombatMath {

    @inline(__always)
    public static func rollVariance(_ varianceMax: UInt64, rng: inout any Randomizer) -> Int {
        guard varianceMax > 0 else { return 0 }
        return Int(rng.uniform(varianceMax &+ 1))
    }

    @inline(__always)
    public static func combinedMitigationPercent(statusPct: Int, armorPct: Int, rules: GameRules) -> Int {
        let raw = Formula.combinedMitigation(statusPct: statusPct, armorPct: armorPct)
        return min(rules.maxMitigationPercent, max(0, raw))
    }

    @inline(__always)
    public static func applyMitigation(base: Int, mitigationPercent: Int) -> Int {
        Formula.finalDamage(base: base, mitigationPercent: mitigationPercent)
    }

    // MARK: Hit chance

    /// Compute percent chance to hit based on SPD differential and tunables.
    public static func hitChancePercent(attacker: Character, defender: Character, rules: GameRules) -> Int {
        let a = attacker.stats[.spd]
        let d = defender.stats[.spd]
        let shift = (a - d) * rules.spdSlopePerPoint
        let pct = rules.baseHitPercent + shift
        return max(rules.minHitPercent, min(rules.maxHitPercent, pct))
    }

    /// Roll a hit against [0,99].
    public static func rollHit(chancePercent: Int, rng: inout any Randomizer) -> (hit: Bool, roll: Int) {
        let r = Int(rng.uniform(100))
        return (r < chancePercent, r)
    }

    // MARK: - Physical attack orchestrator

    /// Full resolution including hit check. Returns 0 damage on miss.
    public static func resolvePhysicalAttack(
        source: Character,
        target: Character,
        weaponDamage: Int,
        baseBonus: Int,
        statusMitigationPercent: Int,
        armorMitigationPercent: Int,
        rng: inout any Randomizer,
        rules: GameRules = .default
    ) -> (hit: Bool, total: Int, variance: Int, mitigation: Int, hitRoll: Int, hitChance: Int) {

        let chance = hitChancePercent(attacker: source, defender: target, rules: rules)
        let (didHit, roll) = rollHit(chancePercent: chance, rng: &rng)
        if !didHit {
            return (false, 0, 0, 0, roll, chance)
        }

        let pre = max(0, baseBonus + source.stats[.str] + weaponDamage)
        let variance = rollVariance(rules.attackVarianceMax, rng: &rng)
        let afterVariance = max(0, pre - variance)
        let mit = combinedMitigationPercent(statusPct: statusMitigationPercent,
                                            armorPct: armorMitigationPercent,
                                            rules: rules)
        let total = applyMitigation(base: afterVariance, mitigationPercent: mit)
        return (true, total, variance, mit, roll, chance)
    }
    
    // Back-compat shim: old API (no hit/miss)
    // Returns damage/variance/mitigation exactly as before, ignoring hit logic.
    @discardableResult
    public static func physicalAttack(
        source: Character,
        target: Character,
        weaponDamage: Int,
        baseBonus: Int,
        statusMitigationPercent: Int,
        armorMitigationPercent: Int,
        rng: inout any Randomizer,
        rules: GameRules = .default
    ) -> (total: Int, variance: Int, mitigation: Int) {
        let res = resolvePhysicalAttack(
            source: source,
            target: target,
            weaponDamage: weaponDamage,
            baseBonus: baseBonus,
            statusMitigationPercent: statusMitigationPercent,
            armorMitigationPercent: armorMitigationPercent,
            rng: &rng,
            rules: rules
        )
        return (res.total, res.variance, res.mitigation)
    }
}
