//
//  Actions.Cleave.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Physical AoE that hits all living foes. Equipment + mitigation aware when A == Character.
public struct Cleave<A: GameActor>: Action, @unchecked Sendable {
    public let base: Int          // flat base before stats/weapon/variance
    public let varianceMax: UInt64

    public init(base: Int = 4, varianceMax: UInt64 = 2) {
        self.base = base
        self.varianceMax = varianceMax
    }

    public func legality(in state: CombatRuntime<A>) -> Bool {
        !state.foes(of: state.currentActor).isEmpty
    }

    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] {
        state.foes(of: state.currentActor)
    }

    public mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event] {
        guard legality(in: state) else { return [] }
        var out: [Event] = []

        // Generic (non-Character) fallback: flat damage to all foes
        let targets = selectTargets(in: state, rng: &rng)
        for t in targets {
            let variance = varianceMax > 0 ? Int(rng.uniform(varianceMax &+ 1)) : 0
            let total = max(0, base - variance)
            if var hp = state.hp(of: t) {
                let before = hp
                hp = max(0, before - total)
                state.setHP(of: t, to: hp)

                out.append(Event(kind: .damage, timestamp: state.tick, data: [
                    "amount": String(total),
                    "hpBefore": String(before),
                    "hpAfter": String(hp),
                    "target": t.name,
                    "source": state.currentActor.name,
                    "aoe": "cleave"
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

// Equipment-aware specialization when A == Character
public extension Cleave where A == Character {
    mutating func perform(in state: inout CombatRuntime<Character>, rng: inout any Randomizer) -> [Event] {
        guard legality(in: state) else { return [] }
        var out: [Event] = []

        let src   = state.currentActor
        let srcEq = state.equipment[src.id] ?? Equipment()
        let weapon = EquipmentMath.weaponDamage(for: src, eq: srcEq)
        let actionBase = base + src.stats[.str] + weapon

        let targets = selectTargets(in: state, rng: &rng)
        for t in targets {
            // Per-target hit check
            if !AccuracyModel.rollHit(attacker: src, defender: t, rng: &rng) {
                out.append(Event(kind: .note, timestamp: state.tick, data: [
                    "result": "miss",
                    "source": src.name,
                    "target": t.name,
                    "aoe": "cleave"
                ]))
                continue
            }

            let variance = varianceMax > 0 ? Int(rng.uniform(varianceMax &+ 1)) : 0
            var beforeMit = max(0, actionBase - variance)

            // Crit per target
            let crit = AccuracyModel.rollCrit(attacker: src, rng: &rng)
            if crit { beforeMit = AccuracyModel.applyCrit(to: beforeMit) }

            // Status + armor mitigation per target
            let statusMit = state.mitigationPercent(for: t)
            let tgtEq     = state.equipment[t.id] ?? Equipment()
            let armorMit  = EquipmentMath.mitigationPercent(from: tgtEq)
            let mitPct    = Formula.combinedMitigation(statusPct: statusMit, armorPct: armorMit)

            let total = Formula.finalDamage(base: beforeMit, mitigationPercent: mitPct)

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
                    "aoe": "cleave"
                ]))

                out.append(Event(kind: .note, timestamp: state.tick, data: [
                    "weapon": String(weapon),
                    "variance": String(variance),
                    "mitigation": String(mitPct),
                    "crit": crit ? "true" : "false",
                    "aoe": "cleave"
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
