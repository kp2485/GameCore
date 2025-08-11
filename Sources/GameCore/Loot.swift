//
//  Loot.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// A weighted entry for a possible item drop.
public struct LootEntry: Sendable, Equatable {
    public let itemId: String
    public let minQty: Int
    public let maxQty: Int
    public let weight: Int          // relative weight; 0 means never drops

    public init(itemId: String, minQty: Int = 1, maxQty: Int = 1, weight: Int = 1) {
        precondition(minQty >= 0 && maxQty >= minQty)
        precondition(weight >= 0)
        self.itemId = itemId
        self.minQty = minQty
        self.maxQty = maxQty
        self.weight = weight
    }
}

/// A collection of loot entries; performs weighted rolls with a fixed number of pulls.
public struct LootBundle: Sendable, Equatable {
    public let pulls: Int           // how many items to roll from this bundle
    public let entries: [LootEntry]

    public init(pulls: Int, entries: [LootEntry]) {
        precondition(pulls >= 0)
        self.pulls = pulls
        self.entries = entries
    }

    /// Deterministic roll given rng; returns (itemId, qty) pairs (qty>0).
    public func roll(rng: inout any Randomizer) -> [(id: String, qty: Int)] {
        guard pulls > 0 else { return [] }
        let pool = entries.filter { $0.weight > 0 }
        guard !pool.isEmpty else { return [] }
        let totalWeight = pool.reduce(0) { $0 + $1.weight }

        var results: [String: Int] = [:]
        for _ in 0..<pulls {
            var pick = Int(rng.uniform(UInt64(totalWeight)))
            var chosen: LootEntry = pool[0]
            for e in pool {
                if pick < e.weight { chosen = e; break }
                pick -= e.weight
            }
            let qtyRange = chosen.maxQty - chosen.minQty
            let qty = chosen.minQty + (qtyRange > 0 ? Int(rng.uniform(UInt64(qtyRange + 1))) : 0)
            if qty > 0 { results[chosen.itemId, default: 0] += qty }
        }
        return results.map { ($0.key, $0.value) }
    }
}
