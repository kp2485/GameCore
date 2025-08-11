//
//  Actions.TargetedAttack.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// A physical attack that uses TargetingMode to select targets.
/// When A == Character, it reuses your equipment + mitigation + accuracy/crit path.
public struct TargetedAttack<A: GameActor>: Action, @unchecked Sendable {
    public var mode: TargetingMode
    public var base: Int
    public var varianceMax: UInt64

    public init(mode: TargetingMode, base: Int = 5, varianceMax: UInt64 = 2) {
        self.mode = mode
        self.base = base
        self.varianceMax = varianceMax
    }

    public func legality(in state: CombatRuntime<A>) -> Bool {
        var probe: any Randomizer = SeededPRNG(seed: 0)
        return !TargetResolver<A>().resolve(mode: mode, state: state, rng: &probe).isEmpty
    }

    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] {
        TargetResolver<A>().resolve(mode: mode, state: state, rng: &rng)
    }

    // Generic fallback (non-Character) — flat damage with variance
    public mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event] {
        guard legality(in: state) else { return [] }
        var out: [Event] = []
        for t in selectTargets(in: state, rng: &rng) {
            let variance = Int(rng.uniform(varianceMax &+ 1))
            let total = max(0, base - variance)
            if var hp = state.hp(of: t) {
                let before = hp
                hp = max(0, before - total)
                state.setHP(of: t, to: hp)
                out.append(Event(kind: .damage, timestamp: state.tick, data: [
                    "amount": String(total),
                    "target": t.name,
                    "source": state.currentActor.name,
                    "mode": String(describing: mode)
                ]))
                if hp == 0 {
                    out.append(Event(kind: .death, timestamp: state.tick, data: [
                        "target": t.name, "by": state.currentActor.name
                    ]))
                }
            }
        }
        return out
    }
}

// Character-specialized implementation reusing equipment + accuracy/crit.
public extension TargetedAttack where A == Character {
    mutating func perform(in state: inout CombatRuntime<Character>, rng: inout any Randomizer) -> [Event] {
        guard legality(in: state) else { return [] }
        var out: [Event] = []

        let src   = state.currentActor
        let srcEq = state.equipment[src.id] ?? Equipment()
        let weapon = EquipmentMath.weaponDamage(for: src, eq: srcEq)
        let actionBase = base + src.stats[.str] + weapon
        let targets = selectTargets(in: state, rng: &rng)

        for t in targets {
            // Hit / miss
            if !AccuracyModel.rollHit(attacker: src, defender: t, rng: &rng) {
                out.append(Event(kind: .note, timestamp: state.tick, data: [
                    "result": "miss", "source": src.name, "target": t.name, "mode": "physical.\(mode)"
                ]))
                continue
            }

            let variance = Int(rng.uniform(varianceMax &+ 1))
            var beforeMit = max(0, actionBase - variance)

            // Crit
            let crit = AccuracyModel.rollCrit(attacker: src, rng: &rng)
            if crit { beforeMit = AccuracyModel.applyCrit(to: beforeMit) }

            // Mitigation
            let statusMit = state.mitigationPercent(for: t)
            let tgtEq     = state.equipment[t.id] ?? Equipment()
            let armorMit  = EquipmentMath.mitigationPercent(from: tgtEq)
            let mitPct    = Formula.combinedMitigation(statusPct: statusMit, armorPct: armorMit)
            let total     = Formula.finalDamage(base: beforeMit, mitigationPercent: mitPct)

            if var hp = state.hp(of: t) {
                let before = hp
                hp = max(0, before - total)
                state.setHP(of: t, to: hp)

                out.append(Event(kind: .damage, timestamp: state.tick, data: [
                    "amount": String(total),
                    "hpBefore": String(before),
                    "hpAfter": String(hp),
                    "target": t.name,
                    "source": src.name,
                    "mode": "physical.\(mode)"
                ]))

                out.append(Event(kind: .note, timestamp: state.tick, data: [
                    "weapon": String(weapon),
                    "variance": String(variance),
                    "mitigation": String(mitPct),
                    "crit": crit ? "true" : "false",
                    "mode": "physical.\(mode)"
                ]))

                if hp == 0 {
                    out.append(Event(kind: .death, timestamp: state.tick, data: [
                        "target": t.name, "by": src.name
                    ]))
                }
            }
        }
        return out
    }
}
