//
//  Spells.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// MARK: - IDs

public struct SpellID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ s: String) { self.rawValue = s }
    public var description: String { rawValue }
}

public enum BuiltInSpells {
    public static let fireBolt   = SpellID("fire_bolt")
    public static let healWounds = SpellID("heal_wounds")
}

// MARK: - Spell protocol

/// A spell is a small, self-contained effect that transforms game state.
/// It is generic over your GameActor type via an associated type `A`.
public protocol Spell<A>: Sendable {
    associatedtype A: GameActor

    /// Stable identifier (used by spellbooks, JSON, etc.)
    static var id: SpellID { get }
    /// Display name (for logs/UI)
    static var name: String { get }
    /// Base mana (MP) cost for `caster` (you can compute from stats/equipment if you like).
    static func mpCost(for caster: A) -> Int

    /// Perform the spell's effect. You should assume the MP has already been paid.
    /// Return any Events you want to surface (damage/heal already exist).
    static func cast(caster: inout A, target: inout A, rng: inout any Randomizer) -> [Event]
}

// MARK: - Errors

public enum SpellError: Error, Equatable, Sendable {
    case unknownSpell
    case notKnown
    case insufficientMP(required: Int, available: Int)
}

// MARK: - Spellbook

public struct Spellbook: Codable, Sendable, Equatable {
    public var known: Set<SpellID>
    public init(_ known: Set<SpellID> = []) { self.known = known }
    public func knows(_ id: SpellID) -> Bool { known.contains(id) }
    public mutating func learn(_ id: SpellID) { known.insert(id) }
}

// MARK: - Spell System

public enum SpellSystem {
    /// Attempt to cast a specific spell type `S`.
    /// - Validates knowledge + MP, deducts MP on success, and executes the effect.
    /// - Uses CoreStat.mp and CoreStat.hp keys.
    @discardableResult
    public static func cast<S: Spell, A>(
        _ spell: S.Type,
        caster: inout A,
        target: inout A,
        book: Spellbook,
        rng: inout any Randomizer
    ) throws -> [Event] where S.A == A, A: GameActor {

        // Knowledge
        guard book.knows(S.id) else { throw SpellError.notKnown }

        // Costing
        let cost = S.mpCost(for: caster)
        let currentMP = caster.stats[CoreStat.mp as! A.K]
        guard currentMP >= cost else {
            throw SpellError.insufficientMP(required: cost, available: currentMP)
        }
        caster.stats.add(CoreStat.mp as! A.K, -cost)

        // Cast
        return S.cast(caster: &caster, target: &target, rng: &rng)
    }
}

// MARK: - Concrete Spells

/// FIRE BOLT: modest fire damage that scales lightly with INT.
/// Damage = base 8 + floor(INT / 4) ± 0..2
public struct FireBolt<A: GameActor>: Spell {
    public static var id: SpellID { BuiltInSpells.fireBolt }
    public static var name: String { "Fire Bolt" }
    public static func mpCost(for caster: A) -> Int { 5 }

    public static func cast(caster: inout A, target: inout A, rng: inout any Randomizer) -> [Event] {
        let intVal = caster.stats[CoreStat.int as! A.K]
        let base = 8 + (intVal / 4)
        let jitter = Int(rng.uniform(3)) // 0..2
        let raw = base + jitter

        // Apply resistance
        let res = ResistanceSystem.percent(for: .fire, actor: target) // 0..100
        let dealt = max(0, (raw * (100 - res)) / 100)

        target.stats.add(CoreStat.hp as! A.K, -dealt)
        return [Event(kind: .damage, timestamp: 0,
                      data: ["spell": name, "amount": "\(dealt)", "type": "fire", "resist": "\(res)"])]
    }
}

/// HEAL WOUNDS: simple direct heal that scales with VIT.
/// Heal = base 6 + floor(VIT / 3) ± 0..2
public struct HealWounds<A: GameActor>: Spell {
    public static var id: SpellID { BuiltInSpells.healWounds }
    public static var name: String { "Heal Wounds" }
    public static func mpCost(for caster: A) -> Int { 4 }

    public static func cast(caster: inout A, target: inout A, rng: inout any Randomizer) -> [Event] {
        let vitVal = caster.stats[CoreStat.vit as! A.K]
        let base = 6 + (vitVal / 3)
        let jitter = Int(rng.uniform(3))
        let heal = base + jitter
        target.stats.add(CoreStat.hp as! A.K, heal)
        return [Event(kind: .heal, timestamp: 0, data: ["spell": name, "amount": "\(heal)"])]
    }
}
