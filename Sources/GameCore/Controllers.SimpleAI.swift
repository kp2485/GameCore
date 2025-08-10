//
//  Controllers.SimpleAI.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Minimal Character AI that performs a single equipment-aware physical attack
/// using a configurable targeting rule.
public struct SimpleAI: Controller {
    public typealias A = Character

    public let equipmentById: [UUID: Equipment]
    public let rule: TargetRule
    /// Inclusive variance range [0...varianceMax] for its attacks.
    public let varianceMax: UInt64

    public init(
        equipmentById: [UUID: Equipment] = [:],
        rule: TargetRule = .firstLivingFoe,
        varianceMax: UInt64 = 2
    ) {
        self.equipmentById = equipmentById
        self.rule = rule
        self.varianceMax = varianceMax
    }

    public func plan(in state: CombatRuntime<Character>, rng: inout any Randomizer) -> ActionPlan<Character>? {
        // If no foes, return nil
        guard !state.foes(of: state.currentActor).isEmpty else { return nil }

        // Capture config for the action thunk
        let rule = self.rule
        let varianceMax = self.varianceMax
        let equipmentById = self.equipmentById

        return ActionPlan { (st: inout CombatRuntime<Character>, r: inout any Randomizer) in
            // Resolve target per rule
            guard let target = ControllerTargeting.resolve(rule: rule, in: st, rng: &r).first else { return [] }

            // Source & target equipment (fallback to empty equipment)
            let srcEq = st.equipment[st.currentActor.id] ?? equipmentById[st.currentActor.id] ?? Equipment()
            let tgtEq = st.equipment[target.id]         ?? equipmentById[target.id]         ?? Equipment()

            // Weapon contribution
            let weapon = EquipmentMath.weaponDamage(for: st.currentActor, eq: srcEq)

            // Base physical attack: 5 + STR + weapon
            let base = 5 + st.currentActor.stats[.str] + weapon
            let variance = varianceMax > 0 ? Int(r.uniform(varianceMax &+ 1)) : 0
            let beforeMit = max(0, base - variance)

            // Combine mitigations: status + armor
            let statusMit = st.mitigationPercent(for: target)
            let armorMit  = EquipmentMath.mitigationPercent(from: tgtEq)
            let mitPct    = Formula.combinedMitigation(statusPct: statusMit, armorPct: armorMit)
            let total     = Formula.finalDamage(base: beforeMit, mitigationPercent: mitPct)

            var out: [Event] = []

            // Apply
            if var hp = st.hp(of: target) {
                let before = hp
                hp = max(0, hp - total)
                st.setHP(of: target, to: hp)

                out.append(Event(kind: .damage, timestamp: st.tick, data: [
                    "amount": String(total),
                    "hpBefore": String(before),
                    "hpAfter": String(hp),
                    "target": target.name,
                    "source": st.currentActor.name
                ]))
                out.append(Event(kind: .note, timestamp: st.tick, data: [
                    "weapon": String(weapon),
                    "variance": String(variance),
                    "mitigation": String(mitPct)
                ]))
                if hp == 0 {
                    out.append(Event(kind: .death, timestamp: st.tick, data: [
                        "target": target.name,
                        "by": st.currentActor.name
                    ]))
                }
            }
            return out
        }
    }
}
