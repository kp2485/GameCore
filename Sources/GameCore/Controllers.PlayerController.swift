//
//  Controllers.PlayerController.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// A player-driven controller that the UI can back with a closure.
/// Supply `nextPlan` that returns an ActionPlan for the current state (or nil to skip).
public struct PlayerController: Controller {
    public typealias A = Character

    /// Provide a plan for the current actor when asked.
    /// Implement this in your UI layer (e.g., from a command queue or a live callback).
    public let nextPlan: @Sendable (_ state: CombatRuntime<Character>) -> ActionPlan<Character>?

    public init(nextPlan: @escaping @Sendable (_ state: CombatRuntime<Character>) -> ActionPlan<Character>?) {
        self.nextPlan = nextPlan
    }

    public func plan(in state: CombatRuntime<Character>, rng: inout any Randomizer) -> ActionPlan<Character>? {
        nextPlan(state)
    }
}
