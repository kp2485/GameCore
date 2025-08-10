//
//  GameSaveRepositoryTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import Testing
@testable import GameCore
@testable import GameDataSwiftData

private func char(_ name: String, _ stats: [CoreStat: Int], tags: Set<String> = []) -> Character {
    Character(name: name, stats: StatBlock(stats), tags: tags)
}

@Suite struct GameSaveRepositoryTests {

    @Test @MainActor
    func saveLoadDeleteRoundTrip() throws {
        let stack = try SDStack(inMemory: true)

        // Seed a couple items
        let items = SDItemRepository(stack: stack)
        try items.upsertWeapon(id: "sw1", name: "Shortsword", tags: ["blade"], baseDamage: 4, scaling: .strDivisor, param: 2)
        try items.upsertArmor(id: "helm", name: "Bronze Helm", tags: ["light"], mitigationPercent: 15)

        // Build a tiny party
        let hero = char("Hero", [.str: 8, .vit: 6, .spd: 6], tags: ["martial"])
        let mage = char("Mage", [.int: 9, .spd: 5], tags: ["arcane"])

        // Equipment & inventory snapshots
        var eqHero = Equipment()
        try eqHero.equip(try #require(try items.fetch(byId: "sw1") as? Weapon), to: .mainHand)
        var eqMage = Equipment()
        try eqMage.equip(try #require(try items.fetch(byId: "helm") as? Armor), to: .head)

        let equipmentById: [UUID: Equipment] = [
            hero.id: eqHero,
            mage.id: eqMage
        ]
        let inventoriesById: [UUID: [String: Int]] = [
            hero.id: ["sw1": 1],
            mage.id: ["helm": 1]
        ]

        let repo = SDGameSaveRepository(stack: stack)

        // Save
        let saveId = try repo.saveGame(name: "Slot A",
                                       members: [hero, mage],
                                       equipmentById: equipmentById,
                                       inventoriesById: inventoriesById,
                                       notes: "Test save")

        // Load
        let loaded = try repo.loadSave(id: saveId)
        #expect(loaded.meta.name == "Slot A")
        #expect(loaded.members.count == 2)
        #expect(loaded.members[0].name == "Hero")
        #expect(loaded.members[1].name == "Mage")

        // Equipment restored by member original UUID
        #expect((loaded.equipmentById[hero.id]?.item(in: .mainHand) as? Weapon)?.id == "sw1")
        #expect((loaded.equipmentById[mage.id]?.item(in: .head) as? Armor)?.id == "helm")

        // Inventories restored
        #expect(loaded.inventoriesById[hero.id]?["sw1"] == 1)
        #expect(loaded.inventoriesById[mage.id]?["helm"] == 1)

        // Latest
        #expect(try repo.loadLatest() == saveId)

        // List & delete
        let list = try repo.listSaves()
        #expect(list.contains { $0.id == saveId })
        try repo.deleteSave(id: saveId)
        #expect(try repo.loadLatest() == nil)
    }

    @Test @MainActor
    func multipleSavesKeepIsolation() throws {
        let stack = try SDStack(inMemory: true)
        let items = SDItemRepository(stack: stack)
        try items.upsertArmor(id: "cap", name: "Cap", tags: ["light"], mitigationPercent: 5)

        let a = char("A", [.str: 6]); let b = char("B", [.str: 7])
        var eqA = Equipment(); let eqB = Equipment()
        try eqA.equip(try #require(try items.fetch(byId: "cap") as? Armor), to: .head)

        let repo = SDGameSaveRepository(stack: stack)

        let id1 = try repo.saveGame(name: "One", members: [a], equipmentById: [a.id: eqA], inventoriesById: [a.id: ["cap":1]], notes: nil)
        let id2 = try repo.saveGame(name: "Two", members: [b], equipmentById: [b.id: eqB], inventoriesById: [:], notes: nil)

        let s1 = try repo.loadSave(id: id1)
        let s2 = try repo.loadSave(id: id2)

        #expect(s1.members[0].name == "A")
        #expect(s2.members[0].name == "B")
        // Equipment isolated per save
        #expect((s1.equipmentById[a.id]?.item(in: .head) as? Armor)?.id == "cap")
        #expect((s2.equipmentById[b.id]?.item(in: .head) as? Armor)?.id == nil)
    }
}
#endif
