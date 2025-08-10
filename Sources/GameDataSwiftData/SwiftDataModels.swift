//
//  SwiftDataModels.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData
import GameCore

// We persist arrays instead of dictionaries for stats to keep the schema simple.
// The order follows CoreStat.allCases.
@Model
public final class RaceEntity {
    @Attribute(.unique) public var id: String
    public var name: String
    public var statBonuses: [Int] // aligned to CoreStat.allCases
    public var tags: [String]

    public init(id: String, name: String, statBonuses: [Int], tags: [String]) {
        self.id = id
        self.name = name
        self.statBonuses = statBonuses
        self.tags = tags
    }
}

@Model
public final class ClassEntity {
    @Attribute(.unique) public var id: String
    public var name: String
    public var minStats: [Int]         // aligned to CoreStat.allCases
    public var allowedWeapons: [String]
    public var allowedArmor: [String]
    public var startingTags: [String]
    public var startingLevel: Int

    public init(
        id: String,
        name: String,
        minStats: [Int],
        allowedWeapons: [String],
        allowedArmor: [String],
        startingTags: [String],
        startingLevel: Int
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

@Model
public final class CharacterEntity {
    public var uuid: UUID
    public var name: String
    public var stats: [Int]      // aligned to CoreStat.allCases
    public var tags: [String]
    public var createdAt: Date

    public init(uuid: UUID = UUID(), name: String, stats: [Int], tags: [String], createdAt: Date = .now) {
        self.uuid = uuid
        self.name = name
        self.stats = stats
        self.tags = tags
        self.createdAt = createdAt
    }
}
#endif
