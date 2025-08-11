//
//  EffectsLibrary.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

public struct Damage<A: GameActor>: Effect {
    public enum Kind: String, Sendable { case physical, fire, frost, shock, poison }
    public let kind: Kind
    public let base: Int
    public let scale: @Sendable (A) -> Int

    public init(kind: Kind, base: Int, scale: @escaping @Sendable (A) -> Int) {
        self.kind = kind; self.base = base; self.scale = scale
    }

    public func apply(
        to target: inout A,
        state: inout CombatRuntime<A>,
        rng: inout any Randomizer
    ) -> [Event] {
        guard var hp = state.hp(of: target) else { return [] }
        let raw = base + scale(state.currentActor)
        let variance = Int(rng.uniform(3)) // 0..2
        let beforeMitigation = max(0, raw - variance)
        let mitigation = state.mitigationPercent(for: target)
        let total = Formula.finalDamage(base: beforeMitigation, mitigationPercent: mitigation)
        let before = hp
        hp = max(0, hp - total)
        state.setHP(of: target, to: hp)
        var data: [String: String] = [
            "kind": kind.rawValue,
            "amount": String(total),
            "hpBefore": String(before),
            "hpAfter": String(hp),
            "target": target.name,
            "source": state.currentActor.name
        ]
        if hp == 0 { data["death"] = "true" }
        return [Event(kind: .damage, timestamp: state.tick, data: data)]
    }
}

public struct Heal<A: GameActor>: Effect {
    public let amount: Int
    public init(_ amount: Int) { self.amount = amount }

    public func apply(
        to target: inout A,
        state: inout CombatRuntime<A>,
        rng: inout any Randomizer
    ) -> [Event] {
        guard var hp = state.hp(of: target) else { return [] }
        let before = hp
        let cap = state.maxHP(of: target)
        hp = min(cap, hp + amount)
        state.setHP(of: target, to: hp)
        return [Event(kind: .heal, timestamp: state.tick, data: [
            "amount": String(amount),
            "hpBefore": String(before),
            "hpAfter": String(hp),
            "target": target.name,
            "source": state.currentActor.name
        ])]
    }
}
