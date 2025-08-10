//
//  ItemPersistenceTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import Testing
@testable import GameCore
@testable import GameDataSwiftData

@Suite struct ItemPersistenceTests {

    @Test @MainActor
    func upsertAndFetchItems() throws {
        let stack = try SDStack(inMemory: true)
        let repo = SDItemRepository(stack: stack)

        try repo.upsertWeapon(id: "sw1", name: "Shortsword", tags: ["blade"], baseDamage: 4, scaling: .strDivisor, param: 2)
        try repo.upsertArmor(id: "cap", name: "Leather Cap", tags: ["light"], mitigationPercent: 10)

        let all = try repo.fetchAll()
        #expect(all.count == 2)
        #expect(all.contains { ($0 as? Weapon)?.name == "Shortsword" })
        #expect(try repo.fetch(byId: "cap") is Armor)
    }

    @Test @MainActor
    func saveAndLoadEquipmentForCharacter() throws {
        let stack = try SDStack(inMemory: true)
        let items = SDItemRepository(stack: stack)
        let loadouts = SDLoadoutStore(stack: stack)

        try items.upsertWeapon(id: "sw1", name: "Shortsword", tags: ["blade"], baseDamage: 4, scaling: .strDivisor, param: 2)
        try items.upsertArmor(id: "helm", name: "Bronze Helm", tags: ["light"], mitigationPercent: 15)

        let heroId = UUID()
        var eq = Equipment()
        // build runtime items from persistence to make sure mapping is consistent
        let sword = try items.fetch(byId: "sw1") as! Weapon
        let helm  = try items.fetch(byId: "helm") as! Armor
        try eq.equip(sword, to: .mainHand)
        try eq.equip(helm,  to: .head)

        try loadouts.saveEquipment(for: heroId, equipment: eq)
        let restored = try loadouts.loadEquipment(for: heroId)

        // Compare by item IDs per slot (Equipment equality uses IDs)
        #expect(restored == eq)
        #expect((restored.item(in: .mainHand) as? Weapon)?.id == "sw1")
        #expect((restored.item(in: .head) as? Armor)?.mitigationPercent == 15)
    }
}
#endif
