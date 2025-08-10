//
//  Definitions.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// Keep these lightweight and data-driven. Extend as we grow.
public struct Race: Sendable, Hashable {
    public let id: String
    public let name: String
    public let statBonuses: [CoreStat: Int]   // additive bonuses
    public let tags: Set<String>              // e.g., "small", "feline", "aquatic"

    public init(id: String, name: String, statBonuses: [CoreStat: Int] = [:], tags: Set<String> = []) {
        self.id = id
        self.name = name
        self.statBonuses = statBonuses
        self.tags = tags
    }
}

public struct ClassDef: Sendable, Hashable {
    public let id: String
    public let name: String
    public let minStats: [CoreStat: Int]      // requirements before/after bonuses? (we’ll use after)
    public let allowedWeapons: Set<String>    // tags: "blade", "bow", "staff"
    public let allowedArmor: Set<String>      // tags: "light", "heavy", "robe"
    public let startingTags: Set<String>      // e.g., "martial", "arcane"
    public let startingLevel: Int

    public init(
        id: String,
        name: String,
        minStats: [CoreStat: Int] = [:],
        allowedWeapons: Set<String> = [],
        allowedArmor: Set<String> = [],
        startingTags: Set<String> = [],
        startingLevel: Int = 1
    ) {
        self.id = id
        self.name = name
        self.minStats = minStats
        self.allowedWeapons = allowedWeapons
        self.allowedArmor = allowedArmor
        self.startingTags = startingTags
        self.startingLevel = startingLevel
    }
}
