//
//  Targeting.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Common targeting modes for actions/spells.
public enum TargetingMode: Sendable, Equatable {
    case selfOnly
    case firstFoe
    case randomFoe
    case allFoes
    case firstAlly
    case allAllies
}

/// Resolves concrete targets from a TargetingMode and current runtime.
public struct TargetResolver<A: GameActor>: Sendable {
    public init() {}

    public func resolve(mode: TargetingMode,
                        state: CombatRuntime<A>,
                        rng: inout any Randomizer) -> [A] {
        switch mode {
        case .selfOnly:
            return [state.currentActor]

        case .firstFoe:
            let foes = state.foes(of: state.currentActor)
            return foes.first.map { [$0] } ?? []

        case .randomFoe:
            let foes = state.foes(of: state.currentActor)
            guard !foes.isEmpty else { return [] }
            let i = Int(rng.uniform(UInt64(foes.count)))
            return [foes[i]]

        case .allFoes:
            return state.foes(of: state.currentActor)

        case .firstAlly:
            // Prefer an ally other than the current actor; fall back to self if solo.
            let all = state.allies(of: state.currentActor)
            if let other = all.first(where: { $0.id != state.currentActor.id }) {
                return [other]
            }
            return [state.currentActor]

        case .allAllies:
            return state.allies(of: state.currentActor)
        }
    }
}
