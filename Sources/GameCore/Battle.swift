//
//  Battle.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public enum BattleOutcome: Sendable, Equatable {
    case ongoing
    case alliesWin
    case foesWin
    case stalemate   // safety cap (e.g., max rounds reached)
}

public struct ActionPlan<A: GameActor>: Sendable {
    public let exec: @Sendable (inout CombatRuntime<A>, inout any Randomizer) -> [Event]
    public init(exec: @escaping @Sendable (inout CombatRuntime<A>, inout any Randomizer) -> [Event]) {
        self.exec = exec
    }
}

public protocol Controller<A>: Sendable {
    associatedtype A: GameActor
    /// Return an action plan for the current actor in `state`, or nil to skip.
    func plan(in state: CombatRuntime<A>, rng: inout any Randomizer) -> ActionPlan<A>?
}

/// Helpers
public extension Encounter {
    var alliesDefeated: Bool { allies.allSatisfy { $0.hp <= 0 } }
    var foesDefeated:   Bool { foes.allSatisfy   { $0.hp <= 0 } }
}
