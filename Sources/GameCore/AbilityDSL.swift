//
//  AbilityDSL.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// MARK: - Ability definition
public struct Ability<A: GameActor>: Sendable {
    public let name: String
    public let costMP: Int
    public let targeting: TargetingMode
    public let effects: [AnyEffect<A>]

    public init(name: String, costMP: Int, targeting: TargetingMode, effects: [AnyEffect<A>]) {
        self.name = name
        self.costMP = costMP
        self.targeting = targeting
        self.effects = effects
    }

    public init(name: String, costMP: Int, targeting: TargetingMode, @EffectBuilder<A> _ build: () -> [AnyEffect<A>]) {
        self.name = name
        self.costMP = costMP
        self.targeting = targeting
        self.effects = build()
    }
}

// MARK: - Result builder
@resultBuilder
public enum EffectBuilder<A: GameActor> {
    public static func buildBlock(_ parts: AnyEffect<A>...) -> [AnyEffect<A>] { parts }
}

// MARK: - Common effects
public struct ApplyStatus<A: GameActor>: Effect {
    public let status: Status
    public init(_ s: Status) { self.status = s }
    public func apply(to target: inout A, state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event] {
        state.apply(status: status, to: target)
        return [Event(kind: .statusApplied, timestamp: state.tick, data: [
            "status": status.id.rawValue,
            "target": target.name
        ])]
    }
}

public struct ModifyStat: Effect {
    public typealias A = Character

    public let key: @Sendable (Character) -> CoreStat
    public let delta: Int

    public init(key: @escaping @Sendable (Character) -> CoreStat, delta: Int) {
        self.key = key
        self.delta = delta
    }

    public func apply(
        to target: inout Character,
        state: inout CombatRuntime<Character>,
        rng: inout any Randomizer
    ) -> [Event] {
        let k = key(target)
        if k == .vit {
            var s = target.stats
            s.add(.vit, delta)
            target.stats = s
            state.overwriteActor(target)
        }
        return [Event(kind: .note, timestamp: state.tick,
                      data: ["modify": "\(delta)", "stat": k.rawValue])]
    }
}
