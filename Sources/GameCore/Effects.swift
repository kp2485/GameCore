//
//  Effects.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// MARK: - Effect protocol & type erasure
public protocol Effect: Sendable {
    associatedtype A: GameActor
    func apply(
        to target: inout A,
        state: inout CombatRuntime<A>,
        rng: inout any Randomizer
    ) -> [Event]
}

public struct AnyEffect<A: GameActor>: Effect {
    private let _apply: @Sendable (inout A, inout CombatRuntime<A>, inout any Randomizer) -> [Event]

    public init<E: Effect>(_ e: E) where E.A == A {
        // no mutable capture needed; call e.apply directly
        self._apply = { target, state, rng in
            e.apply(to: &target, state: &state, rng: &rng)
        }
    }

    public func apply(
        to target: inout A,
        state: inout CombatRuntime<A>,
        rng: inout any Randomizer
    ) -> [Event] {
        _apply(&target, &state, &rng)
    }
}
