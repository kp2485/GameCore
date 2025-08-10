//
//  SwiftDataAdaptersTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import Testing
import SwiftData
@testable import GameCore
@testable import GameDataSwiftData

@Suite struct SwiftDataAdaptersTests {

    @Test @MainActor
    func seedAndFetchRacesAndClasses() throws {
        let stack = try SDStack(inMemory: true)
        let raceRepo = SDRaceRepository(stack: stack)
        let classRepo = SDClassRepository(stack: stack)

        try raceRepo.upsert(Race(id: "human", name: "Human", statBonuses: [.str: 1, .int: 1], tags: []))
        try raceRepo.upsert(Race(id: "dwarf", name: "Dwarf", statBonuses: [.vit: 2], tags: ["stout"]))

        try classRepo.upsert(ClassDef(id: "fighter", name: "Fighter",
                                      minStats: [.str: 6, .vit: 6],
                                      allowedWeapons: ["blade", "blunt"],
                                      allowedArmor: ["light", "heavy"],
                                      startingTags: ["martial"]))
        try classRepo.upsert(ClassDef(id: "mage", name: "Mage",
                                      minStats: [.int: 7],
                                      allowedWeapons: ["staff"],
                                      allowedArmor: ["robe"],
                                      startingTags: ["arcane"]))

        let races = try raceRepo.allRaces()
        let classes = try classRepo.allClasses()
        #expect(races.count == 2)
        #expect(classes.count == 2)
        #expect(try raceRepo.race(id: "human")?.name == "Human")
        #expect(try classRepo.class(id: "mage")?.name == "Mage")
    }

    @Test @MainActor
    func saveAndLoadCharacters() throws {
        let stack = try SDStack(inMemory: true)
        let store = SDCharacterStore(stack: stack)

        let c = Character(name: "Arden", stats: StatBlock([.str: 7, .vit: 6, .int: 3]), tags: ["martial"])
        let id = try store.save(c)

        let rows = try store.fetchAll()
        #expect(rows.count == 1)
        #expect(rows.first?.id == id)
        #expect(rows.first?.character.name == "Arden")

        try store.delete(id: id)
        #expect(try store.fetchAll().isEmpty)
    }
}
#endif
