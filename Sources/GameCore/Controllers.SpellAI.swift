//
//  Controllers.SpellAI.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Simple spellcasting controller:
/// - If any ally is below `healThresholdPercent` of max HP and caster knows HealWounds → heal the lowest-HP ally.
/// - Else if caster knows FireBolt and has MP → attack the first living foe.
/// - Else returns nil (your loop will just tick statuses or the next controller can act).
public struct SpellAI: Controller {
    public typealias A = Character

    public let spellbooksById: [UUID: Spellbook]
    public let healThresholdPercent: Int  // 0...100

    public init(spellbooksById: [UUID: Spellbook],
                healThresholdPercent: Int = 50) {
        self.spellbooksById = spellbooksById
        self.healThresholdPercent = max(0, min(100, healThresholdPercent))
    }

    public func plan(in state: CombatRuntime<Character>, rng: inout any Randomizer) -> ActionPlan<Character>? {
        let caster = state.currentActor
        guard let book = spellbooksById[caster.id] else { return nil }

        // Helper closures -----------------------------------------------------
        @inline(__always)
        func canAfford<S: Spell<Character>>(_ s: S.Type, caster: Character) -> Bool {
            state.mp(of: caster) >= S.mpCost(for: caster)
        }
        @inline(__always)
        func knows(_ id: SpellID) -> Bool { book.knows(id) }

        // 1) Try to HEAL lowest-HP ally under threshold
        if knows(BuiltInSpells.healWounds) && canAfford(HealWounds<Character>.self, caster: caster) {
            let allies = state.allies(of: caster)
            if let (ally, allyHP, allyMax) = allies
                .compactMap({ a -> (Character, Int, Int)? in
                    guard let hp = state.hp(of: a) else { return nil }
                    return (a, hp, state.maxHP(of: a))
                 })
                .min(by: { $0.1 * 100 / max(1, $0.2) < $1.1 * 100 / max(1, $1.2) }),
               allyHP * 100 / max(1, allyMax) <= healThresholdPercent {

                // Build plan to heal this ally
                return ActionPlan { (st: inout CombatRuntime<Character>, r: inout any Randomizer) in
                    // Spend MP up front from runtime
                    let cost = HealWounds<Character>.mpCost(for: caster)
                    guard st.spendMP(of: caster, cost: cost) else { return [] }

                    // Use copies to get canonical events
                    var casterCopy = caster
                    var targetCopy = ally
                    let ev = HealWounds<Character>.cast(caster: &casterCopy, target: &targetCopy, rng: &r)

                    // Apply heal to runtime target
                    applyHP(from: ev, to: ally, in: &st)

                    // Prepend action marker similar to other actions
                    return [Event(kind: .action, timestamp: st.tick, data: [
                        "spell": "Heal Wounds", "actor": caster.name, "mpCost": "\(cost)"
                    ])] + ev
                }
            }
        }

        // 2) Otherwise FIRE BOLT at the first living foe
        if knows(BuiltInSpells.fireBolt) && canAfford(FireBolt<Character>.self, caster: caster) {
            if let foe = state.foes(of: caster).first {
                return ActionPlan { (st: inout CombatRuntime<Character>, r: inout any Randomizer) in
                    let cost = FireBolt<Character>.mpCost(for: caster)
                    guard st.spendMP(of: caster, cost: cost) else { return [] }

                    var casterCopy = caster
                    var targetCopy = foe
                    let ev = FireBolt<Character>.cast(caster: &casterCopy, target: &targetCopy, rng: &r)

                    applyHP(from: ev, to: foe, in: &st)

                    return [Event(kind: .action, timestamp: st.tick, data: [
                        "spell": "Fire Bolt", "actor": caster.name, "mpCost": "\(cost)"
                    ])] + ev
                }
            }
        }

        // 3) No viable spell
        return nil
    }
}

// MARK: - Event application helpers

@inline(__always)
private func parseInt(_ s: String?) -> Int? {
    guard let s, let v = Int(s) else { return nil }
    return v
}

private func applyHP(from events: [Event], to target: Character, in state: inout CombatRuntime<Character>) {
    var delta = 0
    for e in events {
        switch e.kind {
        case .damage:
            if let amt = parseInt(e.data["amount"]) { delta -= amt }
        case .heal:
            if let amt = parseInt(e.data["amount"]) { delta += amt }
        default:
            break
        }
    }
    if delta != 0, let hp0 = state.hp(of: target) {
        let maxHP = state.maxHP(of: target)
        let hp1 = max(0, min(maxHP, hp0 + delta))
        state.setHP(of: target, to: hp1)

        if hp1 == 0 {
            state.applyDeathEvent(for: target)
        }
    }
}

// Small sugar to emit a death event when HP hits 0 (optional).
private extension CombatRuntime where A == Character {
    mutating func applyDeathEvent(for target: Character) {
        // This appends an Event via an ActionPlan usually; since we don't have the log here,
        // we leave it to the controller's returned events. Kept for future extension.
    }
}
