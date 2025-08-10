//
//  DefaultSeed.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import GameCore

@MainActor
public enum DefaultSeed {
    public static func seedBasicContent(
        races: SDRaceRepository,
        classes: SDClassRepository,
        items: SDItemRepository
    ) throws {
        // Races
        try races.upsert(Race(id: "human", name: "Human", statBonuses: [.str: 1, .int: 1], tags: []))
        try races.upsert(Race(id: "dwarf", name: "Dwarf", statBonuses: [.vit: 2], tags: ["stout"]))

        // Classes
        try classes.upsert(ClassDef(
            id: "fighter", name: "Fighter",
            minStats: [.str: 6, .vit: 6],
            allowedWeapons: ["blade", "blunt"],
            allowedArmor: ["light", "heavy"],
            startingTags: ["martial"], startingLevel: 1
        ))
        try classes.upsert(ClassDef(
            id: "mage", name: "Mage",
            minStats: [.int: 7],
            allowedWeapons: ["staff"],
            allowedArmor: ["robe"],
            startingTags: ["arcane"], startingLevel: 1
        ))

        // Items
        try items.upsertWeapon(id: "sw1", name: "Shortsword", tags: ["blade"], baseDamage: 4, scaling: .strDivisor, param: 2)
        try items.upsertArmor(id: "helm", name: "Bronze Helm", tags: ["light"], mitigationPercent: 15)
    }
}
#endif
