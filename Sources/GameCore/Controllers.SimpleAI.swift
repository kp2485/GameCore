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
        let equipmentById = self.equipmentById

        return ActionPlan { (st: inout CombatRuntime<Character>, r: inout any Randomizer) in
            // Resolve target per rule
            guard let target = ControllerTargeting.resolve(rule: rule, in: st, rng: &r).first else { return [] }

            // Source & target equipment (fallback to empty equipment)
            let srcEq = st.equipment[st.currentActor.id] ?? equipmentById[st.currentActor.id] ?? Equipment()
            let tgtEq = st.equipment[target.id]         ?? equipmentById[target.id]         ?? Equipment()

            // Weapon contribution
            let weapon  = EquipmentMath.weaponDamage(for: st.currentActor, eq: srcEq)
            let statusM = st.mitigationPercent(for: target)
            let armorM  = EquipmentMath.mitigationPercent(from: tgtEq)

            let res = CombatMath.resolvePhysicalAttack(
                source: st.currentActor,
                target: target,
                weaponDamage: weapon,
                baseBonus: 5,
                statusMitigationPercent: statusM,
                armorMitigationPercent: armorM,
                rng: &r,
                rules: .default
            )

            var out: [Event] = []

            if !res.hit {
                out.append(Event(kind: .note, timestamp: st.tick, data: [
                    "source": st.currentActor.name,
                    "target": target.name,
                    "result": "miss",
                    "hitRoll": String(res.hitRoll),
                    "hitChance": String(res.hitChance)
                ]))
                return out
            }

            if var hp = st.hp(of: target) {
                let before = hp
                hp = max(0, hp - res.total)
                st.setHP(of: target, to: hp)

                out.append(Event(kind: .damage, timestamp: st.tick, data: [
                    "amount": String(res.total),
                    "hpBefore": String(before),
                    "hpAfter": String(hp),
                    "target": target.name,
                    "source": st.currentActor.name
                ]))
                out.append(Event(kind: .note, timestamp: st.tick, data: [
                    "weapon": String(weapon),
                    "variance": String(res.variance),
                    "mitigation": String(res.mitigation),
                    "hitRoll": String(res.hitRoll),
                    "hitChance": String(res.hitChance)
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
