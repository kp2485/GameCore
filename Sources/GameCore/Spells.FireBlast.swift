//
//  Spells.FireBlast.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Simple single-target fire damage spell. The caller (e.g. `CastAllFoes`)
/// can fan this out across many targets to make it AoE.
public struct FireBlast<A: GameActor>: Spell {
    public static var id: SpellID { SpellID("fireBlast") }
    public static var name: String { "Fire Blast" }

    /// Medium MP cost with light INT scaling for Characters.
    public static func mpCost(for caster: A) -> Int {
        if let c = caster as? Character { return max(6, 10 + (c.stats[.int] / 10)) }
        return 10
    }

    /// Returns events; caller applies the HP change to the runtime.
    @discardableResult
    public static func cast(
        caster: inout A,
        target: inout A,
        rng: inout any Randomizer
    ) -> [Event] {
        // Base + INT scaling if Character
        let base = 8
        let scale: Int = {
            if let c = caster as? Character { return c.stats[.int] / 3 }
            return 2
        }()

        // Variance 0..2
        let variance = Int(rng.uniform(3))
        let raw = max(0, base + scale - variance)

        // Elemental resistance via tags like "resist:fire=50"
        let resistPct: Int = {
            if let t = target as? Character {
                return parseResistancePercent(for: "fire", tags: t.tags)
            }
            return 0
        }()

        let mitigated = Formula.finalDamage(base: raw, mitigationPercent: resistPct)

        return [
            Event(kind: .damage, timestamp: 0, data: [
                "amount": String(mitigated),
                "element": "fire",
                "spell": Self.name
            ])
        ]
    }

    // MARK: - Local helpers

    /// Parse a resistance tag like "resist:fire=50" to get a percent (0...100).
    private static func parseResistancePercent(for element: String, tags: Set<String>) -> Int {
        // very forgiving: lowercase compare, trims spaces
        let needle = "resist:\(element.lowercased())="
        for t in tags {
            let s = t.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard s.hasPrefix(needle) else { continue }
            let valStr = s.dropFirst(needle.count)
            if let v = Int(valStr) { return max(0, min(100, v)) }
        }
        return 0
    }
}
