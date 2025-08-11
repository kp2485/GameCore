//
//  SpellAction.CastWithTargeting.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Generic spell cast that targets using TargetingMode. Spends MP once for the cast,
/// then applies the spell per resolved target.
public struct CastWithTargeting<A: GameActor, S: Spell<A>>: Action, @unchecked Sendable {
    public var mode: TargetingMode
    public init(mode: TargetingMode) { self.mode = mode }

    public func legality(in state: CombatRuntime<A>) -> Bool {
        let caster = state.currentActor
        var probe: any Randomizer = SeededPRNG(seed: 0)
        let hasTargets = !TargetResolver<A>().resolve(mode: mode, state: state, rng: &probe).isEmpty
        return hasTargets && state.mp(of: caster) >= S.mpCost(for: caster)
    }

    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] {
        TargetResolver<A>().resolve(mode: mode, state: state, rng: &rng)
    }

    public mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event] {
        guard legality(in: state) else { return [] }
        var out: [Event] = []
        let caster = state.currentActor
        let cost = S.mpCost(for: caster)
        guard state.spendMP(of: caster, cost: cost) else {
            out.append(Event(kind: .note, timestamp: state.tick, data: [
                "spell": S.name, "reason": "insufficientMP"
            ]))
            return out
        }
        out.append(Event(kind: .action, timestamp: state.tick, data: [
            "spell": S.name, "actor": caster.name, "mpCost": "\(cost)", "mode": String(describing: mode)
        ]))

        for t in selectTargets(in: state, rng: &rng) {
            var casterCopy = caster
            var targetCopy = t
            let ev = S.cast(caster: &casterCopy, target: &targetCopy, rng: &rng)
            out += ev
            if let dealt = ev
                .filter({ $0.kind == .damage })
                .compactMap({ Int($0.data["amount"] ?? "") })
                .reduce(0, +) as Int?,
               var hp = state.hp(of: t) {
                let before = hp
                hp = max(0, before - dealt)
                state.setHP(of: t, to: hp)
                out.append(Event(kind: .note, timestamp: state.tick, data: [
                    "apply": "damage", "amount": String(dealt), "target": t.name, "hpBefore": String(before), "hpAfter": String(hp)
                ]))
                if hp == 0 {
                    out.append(Event(kind: .death, timestamp: state.tick, data: [
                        "target": t.name, "by": caster.name, "cause": S.name
                    ]))
                }
            }
        }
        return out
    }
}
