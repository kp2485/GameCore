//
//  Encounters.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation
import GameCore // for Randomizer

public struct EncounterTable: Sendable, Codable, Hashable {
    public struct Entry: Sendable, Codable, Hashable {
        public var weight: Int
        public var battleId: String
        public init(weight: Int, battleId: String) { self.weight = max(0, weight); self.battleId = battleId }
    }
    public var entries: [Entry]
    public var stepsPerCheck: Int  // e.g. check every N steps
    public var chancePercent: Int  // 0..100

    public init(entries: [Entry], stepsPerCheck: Int, chancePercent: Int) {
        self.entries = entries
        self.stepsPerCheck = max(1, stepsPerCheck)
        self.chancePercent = min(max(0, chancePercent), 100)
    }

    /// Returns selected battle id or nil if no trigger.
    public func roll(stepCount: Int, rng: inout any Randomizer) -> String? {
        guard stepCount % stepsPerCheck == 0 else { return nil }
        let roll = Int(rng.uniform(100)) // 0..99
        guard roll < chancePercent else { return nil }
        return pickWeighted(rng: &rng)
    }

    public func pickWeighted(rng: inout any Randomizer) -> String? {
        let total = entries.reduce(0) { $0 + max(0, $1.weight) }
        guard total > 0 else { return nil }
        var r = Int(rng.uniform(UInt64(total))) // 0..total-1
        for e in entries {
            let w = max(0, e.weight)
            if r < w { return e.battleId }
            r -= w
        }
        return entries.last?.battleId
    }
}
