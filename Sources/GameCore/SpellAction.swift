//
//  SpellAction.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Cast any `Spell<A>` through your Action pipeline, using the required instance methods:
///  - legality(in:)
///  - selectTargets(in:rng:)
///  - perform(in:rng:)
///
/// NOTE: This implementation DOES NOT mutate `CombatRuntime` directly (its `encounter` setter
/// is not accessible here). Instead, it returns the `Event`s produced by the spell cast.
/// Your engine’s event application phase should commit those events to runtime state.
public struct CastSpell<A: GameActor, S: Spell<A>>: Action {
    public let spell: S.Type
    public var book: Spellbook

    public init(_ spell: S.Type, book: Spellbook) {
        self.spell = spell
        self.book = book
    }

    // MARK: - Legality
    /// Legal if the caster knows the spell and has enough MP for its cost.
    public func legality(in state: CombatRuntime<A>) -> Bool {
        let caster = state.currentActor
        guard book.knows(S.id) else { return false }
        let cost = S.mpCost(for: caster)
        let mp = caster.stats[CoreStat.mp as! A.K]
        return mp >= cost
    }

    // MARK: - Target selection
    /// Pick the first available foe (simple, deterministic). If there are no foes, return [].
    /// We return concrete `A` values (snapshots) because this method is read-only by design.
    public func selectTargets(in state: CombatRuntime<A>, rng: inout any Randomizer) -> [A] {
        switch state.side {
        case .allies:
            if let first = state.encounter.foes.first?.base { return [first] }
        case .foes:
            if let first = state.encounter.allies.first?.base { return [first] }
        }
        return []
    }

    // MARK: - Perform
    /// Execute the cast logically and return Events. This does NOT write back into `state`
    /// because `CombatRuntime`’s `encounter` is not writable here; your engine should apply
    /// the returned events to runtime (same pattern as other actions in your codebase).
    @discardableResult
    public mutating func perform(in state: inout CombatRuntime<A>, rng: inout any Randomizer) -> [Event] {
        // Guard legality (engine usually checks this, but it’s cheap and safe).
        guard legality(in: state) else { return [] }

        // Resolve caster/target snapshots (local mutables for SpellSystem).
        var caster = state.currentActor

        // Choose target deterministically the same way as `selectTargets`.
        var target: A? = nil
        switch state.side {
        case .allies:
            target = state.encounter.foes.first?.base
        case .foes:
            target = state.encounter.allies.first?.base
        }
        guard var t = target else { return [] }

        // SpellSystem handles MP cost, knowledge, and effect on the local copies.
        do {
            let events = try SpellSystem.cast(S.self, caster: &caster, target: &t, book: book, rng: &rng)
            // Return events for the engine to apply. We deliberately do not push
            // mutated actor copies back into `state` here.
            return events
        } catch {
            return []
        }
    }
}
