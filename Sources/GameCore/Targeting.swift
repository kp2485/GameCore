//
//  Targeting.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public enum Targeting: Sendable {
    case selfOnly
    case singleEnemy
    case allEnemies
    case singleAlly
    case allAllies
}

public struct TargetResolver<A: GameActor>: Sendable {
    public init() {}
    public func resolve(
        mode: Targeting,
        state: CombatRuntime<A>,
        rng: inout any Randomizer
    ) -> [A] {
        switch mode {
        case .selfOnly:
            return [state.currentActor]
        case .singleEnemy:
            let es = state.foes(of: state.currentActor)
            return es.first.map { [$0] } ?? []
        case .allEnemies:
            return state.foes(of: state.currentActor)
        case .singleAlly:
            // first living ally (could prefer lowest HP later)
            let allies = state.allies(of: state.currentActor)
            return allies.first.map { [$0] } ?? []
        case .allAllies:
            return state.allies(of: state.currentActor)
        }
    }
}
