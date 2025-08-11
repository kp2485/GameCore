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
        rng: inout any Randomizer,
        rules: GameRules = .default
    ) -> [Event] {
        var out: [Event] = []
        let foes = state.foes(of: state.currentActor)
        guard let target = foes.first else { return out }
        
        let srcEq = state.equipment[state.currentActor.id] ?? Equipment()
        let tgtEq = state.equipment[target.id] ?? Equipment()
        
        let weapon  = EquipmentMath.weaponDamage(for: state.currentActor, eq: srcEq)
        let statusM = state.mitigationPercent(for: target)
        let armorM  = EquipmentMath.mitigationPercent(from: tgtEq)
        
        let result = CombatMath.resolvePhysicalAttack(
            source: state.currentActor,
            target: target,
            weaponDamage: weapon,
            baseBonus: 5,
            statusMitigationPercent: statusM,
            armorMitigationPercent: armorM,
            rng: &rng,
            rules: rules
        )
        
        // Log hit or miss
        if !result.hit {
            out.append(Event(kind: .note, timestamp: state.tick, data: [
                "source": state.currentActor.name,
                "target": target.name,
                "result": "miss",
                "hitRoll": String(result.hitRoll),
                "hitChance": String(result.hitChance)
            ]))
            return out
        }
        
        // Apply damage
        if var hp = state.hp(of: target) {
            let before = hp
            hp = max(0, before - result.total)
            state.setHP(of: target, to: hp)
            
            out.append(Event(kind: .damage, timestamp: state.tick, data: [
                "amount": String(result.total),
                "hpBefore": String(before),
                "hpAfter": String(hp),
                "target": target.name,
                "source": state.currentActor.name
            ]))
            out.append(Event(kind: .note, timestamp: state.tick, data: [
                "weapon": String(weapon),
                "variance": String(result.variance),
                "mitigation": String(result.mitigation),
                "hitRoll": String(result.hitRoll),
                "hitChance": String(result.hitChance)
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
