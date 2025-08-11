//
//  SpellAction.CastAllFoes.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Casts a spell once (MP) and applies its single-target effect to *all living foes*.
/// Generic over both Actor and Spell.
public struct CastAllFoes<A: GameActor, S: Spell<A>>: Action, @unchecked Sendable {
    public init() {}

    public func legality(in state: CombatRuntime<A>) -> Bool {
        let caster = state.currentActor
        let canPay = state.mp(of: caster) >= S.mpCost(for: caster)
        return canPay && !state.foes(of: caster).isEmpty
    }

    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] {
        state.foes(of: state.currentActor)
    }

    public mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event] {
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
            "spell": S.name, "actor": caster.name, "mpCost": "\(cost)", "aoe": "allFoes"
        ]))

        // Apply spell per target, updating runtime HP from the events each time.
        let targets = selectTargets(in: state, rng: &rng)
        for t in targets {
            var casterCopy = caster
            var targetCopy = t
            let ev = S.cast(caster: &casterCopy, target: &targetCopy, rng: &rng)
            out += ev

            // Reduce HP based on "amount" from events
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
