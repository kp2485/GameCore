//
//  Actions.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// MARK: - Action protocol (3-method shape)
public protocol Action: Sendable {
    associatedtype A: GameActor
    func legality(in state: CombatRuntime<A>) -> Bool
    func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A]
    mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event]
}

// MARK: - Basic Attack (uses your Damage<A>.apply(to:state:rng:))
public struct Attack<A: GameActor>: Action, @unchecked Sendable {
    public var damage: Damage<A>
    public init(damage: Damage<A>) { self.damage = damage }

    public func legality(in state: CombatRuntime<A>) -> Bool {
        !state.foes(of: state.currentActor).isEmpty
    }

    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] {
        let foes = state.foes(of: state.currentActor)
        return foes.isEmpty ? [] : [foes[0]]
    }

    @discardableResult
    public mutating func perform(
        in state: inout CombatRuntime<A>,
        rng: inout any Randomizer
    ) -> [Event] {
        guard legality(in: state) else { return [] }
        var out: [Event] = []

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

    /// Equipment-aware physical attack with hit/miss/crit, status + armor mitigation.
    public mutating func performWithEquipment(
        in state: inout CombatRuntime<Character>,
        rng: inout any Randomizer
    ) -> [Event] {
        var out: [Event] = []

        let src  = state.currentActor
        let foes = state.foes(of: src)
        guard let target = foes.first else { return out }

        // Hit / Miss check
        if !AccuracyModel.rollHit(attacker: src, defender: target, rng: &rng) {
            out.append(Event(kind: .note, timestamp: state.tick, data: [
                "result": "miss",
                "source": src.name,
                "target": target.name
            ]))
            return out
        }

        // Equipment
        let srcEq = state.equipment[src.id] ?? Equipment()
        let tgtEq = state.equipment[target.id] ?? Equipment()

        // Weapon damage contribution
        let weapon = EquipmentMath.weaponDamage(for: src, eq: srcEq)

        // Base before variance/mitigation: 5 + STR + weapon
        let baseBonus = 5
        let actionBase = baseBonus + src.stats[.str] + weapon

        // Variance 0..2
        let variance = Int(rng.uniform(3))
        var beforeMitigation = max(0, actionBase - variance)

        // Crit?
        let crit = AccuracyModel.rollCrit(attacker: src, rng: &rng)
        if crit {
            beforeMitigation = AccuracyModel.applyCrit(to: beforeMitigation)
        }

        // Status + armor mitigation
        let statusMit = state.mitigationPercent(for: target)
        let armorMit  = EquipmentMath.mitigationPercent(from: tgtEq)
        let combined  = Formula.combinedMitigation(statusPct: statusMit, armorPct: armorMit)

        let total = Formula.finalDamage(base: beforeMitigation, mitigationPercent: combined)

        // Apply damage
        if var hp = state.hp(of: target) {
            let before = hp
            hp = max(0, before - total)
            state.setHP(of: target, to: hp)

            out.append(Event(kind: .damage, timestamp: state.tick, data: [
                "amount": String(total),
                "hpBefore": String(before),
                "hpAfter": String(hp),
                "target": target.name,
                "source": src.name
            ]))

            // telemetry
            out.append(Event(kind: .note, timestamp: state.tick, data: [
                "weapon": String(weapon),
                "variance": String(variance),
                "mitigation": String(combined),
                "crit": crit ? "true" : "false"
            ]))

            if hp == 0 {
                out.append(Event(kind: .death, timestamp: state.tick, data: [
                    "target": target.name,
                    "by": src.name
                ]))
            }
        }

        return out
    }
}

public extension Attack {
    init() {
        self.damage = Damage(kind: .physical, base: 5, scale: { (_: A) -> Int in 3 })
    }
}

public struct Cast<A: GameActor>: Action, @unchecked Sendable {
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
public struct Defend<A: GameActor>: Action, @unchecked Sendable {
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
