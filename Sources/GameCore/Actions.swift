//
//  Actions.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// MARK: - Action protocol
public protocol Action: Sendable {
    associatedtype A: GameActor
    func legality(in state: CombatRuntime<A>) -> Bool
    func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A]
    mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event]
}

// MARK: - Basic Attack
public struct Attack<A: GameActor>: Action {
    public init() {}
    
    public func legality(in state: CombatRuntime<A>) -> Bool {
        !state.foes(of: state.currentActor).isEmpty
    }
    
    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] {
        let foes = state.foes(of: state.currentActor)
        return foes.isEmpty ? [] : [foes[0]]
    }
    
    public mutating func perform(
        in state: inout CombatRuntime<A>,
        rng: inout any Randomizer  // <- existential
    ) -> [Event] {
        var out: [Event] = []
        let damage = Damage<A>(
            kind: .physical,
            base: 5,
            scale: { actor in
                if let c = actor as? Character { return c.stats[.str] }
                return 3
            }
        )
        
        for var target in selectTargets(in: state, rng: &rng) {
            out += damage.apply(to: &target, state: &state, rng: &rng)
            if state.hp(of: target) == 0 {
                out.append(Event(kind: .death, timestamp: state.tick, data: [
                    "target": target.name,
                    "by": state.currentActor.name
                ]))
            }
        }
        return out
    }
}

// Equipment-aware variant that keeps your original Attack<A> untouched.
// Call `performWithEquipment` when A == Character.
extension Attack where A == Character {

    /// Performs a basic physical attack that:
    /// - adds weapon damage (main/off-hand),
    /// - applies status + armor mitigation,
    /// - updates HP and emits events.
    ///
    /// Targeting: first living foe (same as your simple Attack).
    /// Variance: uniform [0, 2] by default (same feel as your base attack).
    public mutating func performWithEquipment(
        in state: inout CombatRuntime<Character>,
        rng: inout any Randomizer
    ) -> [Event] {
        var out: [Event] = []

        // Resolve default target = first living foe
        let foes = state.foes(of: state.currentActor)
        guard let target = foes.first else { return out }

        // Pull equipment for source & target (if not present, treat as unarmed/unarmored)
        let srcEq = state.equipment[state.currentActor.id] ?? Equipment()
        let tgtEq = state.equipment[target.id] ?? Equipment()

        // Weapon contribution (base + scaling) from main/off hand
        let weapon = EquipmentMath.weaponDamage(for: state.currentActor, eq: srcEq)

        // Raw action base before variance & mitigation:
        //   5 (flat) + STR + weapon
        let baseBonus = 5
        let actionBase = baseBonus + state.currentActor.stats[.str] + weapon

        // Variance 0..2
        let variance = Int(rng.uniform(3))
        let beforeMitigation = max(0, actionBase - variance)

        // Status mitigation from runtime + armor mitigation from equipment
        let statusMit = state.mitigationPercent(for: target)
        let armorMit  = EquipmentMath.mitigationPercent(from: tgtEq)
        let combined  = Formula.combinedMitigation(statusPct: statusMit, armorPct: armorMit)

        // Final damage
        let total = Formula.finalDamage(base: beforeMitigation, mitigationPercent: combined)

        // Apply & emit events
        if var hp = state.hp(of: target) {
            let before = hp
            hp = max(0, before - total)
            state.setHP(of: target, to: hp)

            out.append(Event(kind: .damage, timestamp: state.tick, data: [
                "amount": String(total),
                "hpBefore": String(before),
                "hpAfter": String(hp),
                "target": target.name,
                "source": state.currentActor.name
            ]))

            out.append(Event(kind: .note, timestamp: state.tick, data: [
                "weapon": String(weapon),
                "variance": String(variance),
                "mitigation": String(combined)
            ]))

            if hp == 0 {
                out.append(Event(kind: .death, timestamp: state.tick, data: [
                    "target": target.name,
                    "by": state.currentActor.name
                ]))
            }
        }

        return out
    }
}

public struct Cast<A: GameActor>: Action {
    public let ability: Ability<A>
    public init(_ ability: Ability<A>) { self.ability = ability }

    public func legality(in state: CombatRuntime<A>) -> Bool {
        // Targeting and MP check (assuming current actor pays)
        var probe: any Randomizer = SeededPRNG(seed: 0)
        let hasTargets = !TargetResolver<A>()
            .resolve(mode: ability.targeting, state: state, rng: &probe)
            .isEmpty
        let canPay = state.mp(of: state.currentActor) >= ability.costMP
        return hasTargets && canPay
    }

    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] {
        TargetResolver<A>().resolve(mode: ability.targeting, state: state, rng: &rng)
    }

    public mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event] {
        var out: [Event] = []
        // Pay MP up-front
        guard state.spendMP(of: state.currentActor, cost: ability.costMP) else {
            out.append(Event(kind: .note, timestamp: state.tick, data: [
                "ability": ability.name, "reason": "insufficientMP"
            ]))
            return out
        }
        out.append(Event(kind: .action, timestamp: state.tick, data: [
            "ability": ability.name, "actor": state.currentActor.name, "mpCost": "\(ability.costMP)"
        ]))

        for var t in selectTargets(in: state, rng: &rng) {
            for eff in ability.effects {
                out += eff.apply(to: &t, state: &state, rng: &rng)
            }
        }
        return out
    }
}

// Defend applies a one-turn shield status (20% mitigation)
public struct Defend<A: GameActor>: Action {
    public init() {}
    public func legality(in state: CombatRuntime<A>) -> Bool { true }
    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] { [state.currentActor] }
    public mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event] {
        var selfCopy = state.currentActor
        let shield = Status(.shield, duration: 1, stacks: 1, rule: .stack(4)) // up to 80% if stacked
        _ = ApplyStatus<A>(shield).apply(to: &selfCopy, state: &state, rng: &rng)
        return [Event(kind: .note, timestamp: state.tick, data: ["defend": state.currentActor.name])]
    }
}

// Utility existential RNG that ignores calls, for legality probes
@inline(__always) private func noRng() -> any Randomizer { SeededPRNG(seed: 0) }
