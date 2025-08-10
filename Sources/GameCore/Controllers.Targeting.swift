//
//  Controllers.Targeting.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Built-in targeting rules for Character AIs.
/// (If you want these generic later, we can parameterize by key paths.)
public enum TargetRule: Sendable {
    case firstLivingFoe
    case lowestHPEnemy
    case highestHPEnemy
    case randomEnemy
    case enemyWithTag(String) // e.g., "arcane", "class:mage"
}

public enum ControllerTargeting: Sendable {
    /// Resolve targets according to a rule. Returns at most one target for now.
    public static func resolve(
        rule: TargetRule,
        in state: CombatRuntime<Character>,
        rng: inout any Randomizer
    ) -> [Character] {
        let foes = state.foes(of: state.currentActor)
        if foes.isEmpty { return [] }

        switch rule {
        case .firstLivingFoe:
            return [foes[0]]

        case .lowestHPEnemy:
            let sorted = foes.sorted { (state.hp(of: $0) ?? .max) < (state.hp(of: $1) ?? .max) }
            return sorted.first.map { [$0] } ?? []

        case .highestHPEnemy:
            let sorted = foes.sorted { (state.hp(of: $0) ?? .min) > (state.hp(of: $1) ?? .min) }
            return sorted.first.map { [$0] } ?? []

        case .randomEnemy:
            let idx = Int(rng.uniform(UInt64(foes.count)))
            return [foes[idx]]

        case .enemyWithTag(let tag):
            if let first = foes.first(where: { $0.tags.contains(tag) }) {
                return [first]
            }
            return [foes[0]] // fallback to first foe
        }
    }
}
