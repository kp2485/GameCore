//
//  GameSaveServiceTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import Testing
@testable import GameCore
@testable import GameDataSwiftData

private func C(_ name: String, _ stats: [CoreStat: Int], tags: Set<String> = []) -> Character {
    Character(name: name, stats: StatBlock(stats), tags: tags)
}

@Suite struct GameSaveServiceTests {

    @Test @MainActor
    func saveLoadListDelete_viaService() throws {
        // In-memory SwiftData stack
        let stack = try SDStack(inMemory: true)

        // Seed a few items we’ll reference in equipment/inventory
        let itemRepo = SDItemRepository(stack: stack)
        try itemRepo.upsertWeapon(id: "sw1", name: "Shortsword", tags: ["blade"], baseDamage: 4, scaling: .strDivisor, param: 2)
        try itemRepo.upsertArmor(id: "helm", name: "Bronze Helm", tags: ["light"], mitigationPercent: 15)
        try itemRepo.upsertArmor(id: "cap",  name: "Cloth Cap", tags: ["light"], mitigationPercent: 5)

        // Build a small party
        let hero = C("Hero", [.str: 9, .vit: 7, .spd: 6], tags: ["martial"])
        let mage = C("Mage", [.int: 10, .spd: 6], tags: ["arcane"])

        // Build equipment mutably, then freeze to immutable lets for @Sendable capture
        var _eqHero = Equipment()
        try _eqHero.equip(try #require(try itemRepo.fetch(byId: "sw1") as? Weapon), to: .mainHand)
        let eqHero = _eqHero

        var _eqMage = Equipment()
        try _eqMage.equip(try #require(try itemRepo.fetch(byId: "helm") as? Armor), to: .head)
        let eqMage = _eqMage

        // Provider that mirrors current “in-memory” game state
        let provider = ClosureGameStateProvider(
            members: { [hero, mage] },
            equipmentBy: { id in
                if id == hero.id { return eqHero }
                if id == mage.id { return eqMage }
                return nil
            },
            inventoryBy: { id in
                if id == hero.id { return ["sw1": 1] }
                if id == mage.id { return ["helm": 1, "cap": 2] }
                return [:]
            }
        )

        // Facade
        let saveRepo = SDGameSaveRepository(stack: stack)
        let service  = GameSaveService(repo: saveRepo, provider: provider)

        // Save current game
        let saveId = try service.saveCurrentGame(name: "Slot A", notes: "Reached level 2")
        #expect(saveId != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))

        // Load latest
        guard let loaded = try service.loadLatestGame() else {
            Issue.record("Expected a latest save but found none")
            return
        }

        // Verify members (order preserved)
        #expect(loaded.members.count == 2)
        #expect(loaded.members[0].name == "Hero")
        #expect(loaded.members[1].name == "Mage")

        // Verify equipment restored by original UUID
        #expect((loaded.equipmentById[hero.id]?.item(in: .mainHand) as? Weapon)?.id == "sw1")
        #expect((loaded.equipmentById[mage.id]?.item(in: .head) as? Armor)?.id == "helm")

        // Verify inventories restored
        #expect(loaded.inventoriesById[hero.id]?["sw1"] == 1)
        #expect(loaded.inventoriesById[mage.id]?["helm"] == 1)
        #expect(loaded.inventoriesById[mage.id]?["cap"] == 2)

        // List saves (should include ours)
        let list = try service.listSaves()
        #expect(list.contains { $0.id == saveId })

        // Delete and confirm absence
        try service.deleteSave(id: saveId)
        #expect(try service.loadLatestGame() == nil)
    }

    @Test @MainActor
    func encounterBuildHelperWorks() throws {
        let stack = try SDStack(inMemory: true)
        let saveRepo = SDGameSaveRepository(stack: stack)

        // Minimal items
        let items = SDItemRepository(stack: stack)
        try items.upsertWeapon(id: "sw1", name: "Sword", tags: ["blade"], baseDamage: 3, scaling: .none, param: 1)

        let a = C("A", [.str: 6, .vit: 6])
        let b = C("B", [.str: 7, .vit: 5])

        // Build equipment mutably, then freeze for capture
        var _eqA = Equipment()
        try _eqA.equip(try #require(try items.fetch(byId: "sw1") as? Weapon), to: .mainHand)
        let eqA = _eqA

        let provider = ClosureGameStateProvider(
            members: { [a, b] },
            equipmentBy: { $0 == a.id ? eqA : Equipment() },
            inventoryBy: { _ in [:] }
        )

        let service = GameSaveService(repo: saveRepo, provider: provider)
        let id = try service.saveCurrentGame(name: "Party AB", notes: nil)
        let loaded = try service.loadGame(id: id)

        // asEncounter helper sets HP to max from stats
        let enc = loaded.asEncounter()
        #expect(enc.allies.count == 2)
        #expect(enc.allies[0].base.name == "A")
        #expect(enc.allies[0].hp == enc.allies[0].base.stats.maxHP)

        // applyEquipment helper sets runtime equipment map
        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        rt.applyEquipment(loaded.equipmentById)
        #expect((rt.equipment[a.id]?.item(in: .mainHand) as? Weapon)?.id == "sw1")
    }
}
#endif
