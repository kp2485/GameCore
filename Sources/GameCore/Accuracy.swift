//
//  Accuracy.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Lightweight accuracy/crit model tuned for classic dungeon crawlers.
/// Deterministic via your Randomizer. Only Character-aware; non-Character callers
/// can treat attacks as always-hit and non-crit.
enum AccuracyModel {
    /// Returns `true` if attack hits. Uses SPD to approximate weapon skill.
    static func rollHit(attacker: Character, defender: Character, rng: inout any Randomizer) -> Bool {
        // Base chances: attacker SPD vs defender SPD.
        let accBase = 60 + attacker.stats[.spd]               // attacker accuracy floor
        let evaBase = 30 + defender.stats[.spd] / 2           // defender evasion floor

        let hitPct = clamp(accBase - evaBase, min: 5, max: 95)
        let roll = Int(rng.uniform(100))                      // 0..99
        return roll < hitPct
    }

    /// Returns `true` if attack crits. Small SPD-driven chance.
    static func rollCrit(attacker: Character, rng: inout any Randomizer) -> Bool {
        // Crit % grows slowly with SPD; cap 25%.
        let critPct = clamp(attacker.stats[.spd] / 4, min: 0, max: 25)
        let roll = Int(rng.uniform(100))
        return roll < critPct
    }

    /// Apply crit multiplier (150%) to a positive damage number.
    static func applyCrit(to damage: Int) -> Int {
        guard damage > 0 else { return damage }
        return Int((Double(damage) * 1.5).rounded(.toNearestOrEven))
    }

    private static func clamp(_ v: Int, min lo: Int, max hi: Int) -> Int {
        if v < lo { return lo }
        if v > hi { return hi }
        return v
    }
}
