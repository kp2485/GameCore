//
//  ItemRepository.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData
import GameCore

@MainActor
public protocol ItemRepository: Sendable {
    func upsertWeapon(id: String, name: String, tags: [String], baseDamage: Int, scaling: ScalingKind, param: Int) throws
    func upsertArmor(id: String, name: String, tags: [String], mitigationPercent: Int) throws
    func fetchAll() throws -> [any Item]
    func fetch(byId id: String) throws -> (any Item)?
}

@MainActor
public final class SDItemRepository: ItemRepository {
    private let stack: SDStack
    public init(stack: SDStack) { self.stack = stack }

    public func upsertWeapon(id: String, name: String, tags: [String], baseDamage: Int, scaling: ScalingKind, param: Int) throws {
        let ctx = stack.context
        let iid = id
        var fd = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == iid })
        fd.fetchLimit = 1
        if let row = try ctx.fetch(fd).first {
            row.name = name
            row.kind = ItemKind.weapon.rawValue
            row.tags = tags
            row.baseDamage = baseDamage
            row.scalingKind = scaling.rawValue
            row.scalingParam = param
            row.mitigationPercent = 0
        } else {
            ctx.insert(ItemEntity(id: id, name: name, kind: ItemKind.weapon.rawValue,
                                  tags: tags, baseDamage: baseDamage,
                                  scalingKind: scaling.rawValue, scalingParam: param))
        }
        try ctx.save()
    }

    public func upsertArmor(id: String, name: String, tags: [String], mitigationPercent: Int) throws {
        let ctx = stack.context
        let iid = id
        var fd = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == iid })
        fd.fetchLimit = 1
        if let row = try ctx.fetch(fd).first {
            row.name = name
            row.kind = ItemKind.armor.rawValue
            row.tags = tags
            row.mitigationPercent = mitigationPercent
            row.baseDamage = 0
            row.scalingKind = ScalingKind.none.rawValue
            row.scalingParam = 1
        } else {
            ctx.insert(ItemEntity(id: id, name: name, kind: ItemKind.armor.rawValue,
                                  tags: tags, mitigationPercent: mitigationPercent))
        }
        try ctx.save()
    }

    public func fetchAll() throws -> [any Item] {
        let ctx = stack.context
        let fd = FetchDescriptor<ItemEntity>(sortBy: [SortDescriptor(\.name)])
        return try ctx.fetch(fd).map(ItemMapper.toRuntimeItem)
    }

    public func fetch(byId id: String) throws -> (any Item)? {
        let ctx = stack.context
        let iid = id
        var fd = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == iid })
        fd.fetchLimit = 1
        return try ctx.fetch(fd).first.map(ItemMapper.toRuntimeItem)
    }
}

// MARK: - Loadout persistence for Character equipment

@MainActor
public protocol LoadoutStore: Sendable {
    func saveEquipment(for character: UUID, equipment: Equipment) throws
    func loadEquipment(for character: UUID) throws -> Equipment
}

@MainActor
public final class SDLoadoutStore: LoadoutStore {
    private let stack: SDStack
    public init(stack: SDStack) { self.stack = stack }

    public func saveEquipment(for character: UUID, equipment: Equipment) throws {
        let ctx = stack.context
        // Delete existing slot rows for this character
        let cid = character
        let delFd = FetchDescriptor<EquipmentSlotEntity>(predicate: #Predicate { $0.characterUUID == cid })
        for row in try ctx.fetch(delFd) { ctx.delete(row) }

        // Insert new slot rows
        for (slot, item) in equipment.bySlot {
            ctx.insert(EquipmentSlotEntity(characterUUID: character, slotRaw: slot.rawValue, itemId: item.id))
        }
        try ctx.save()
    }

    @MainActor
    public func loadEquipment(for character: UUID) throws -> Equipment {
        let ctx = stack.context

        // 1) Fetch this character’s equipment slot rows
        let cid = character
        let slotFd = FetchDescriptor<EquipmentSlotEntity>(predicate: #Predicate { $0.characterUUID == cid })
        let rows = try ctx.fetch(slotFd)

        // 2) Build the set/array of item IDs we need
        let idSet = Set(rows.map { $0.itemId })
        if idSet.isEmpty { return Equipment() }
        let ids = Array(idSet) // capture outside the macro

        // 3) Fetch only those items (single-expression predicate)
        var itemFd = FetchDescriptor<ItemEntity>(predicate: #Predicate { ids.contains($0.id) })
        itemFd.sortBy = [SortDescriptor(\.id)]
        let itemRows = try ctx.fetch(itemFd)
        let itemsById = itemRows.reduce(into: [String: ItemEntity]()) { $0[$1.id] = $1 }

        // 4) Rebuild Equipment by slot
        var bySlot: [EquipSlot: any Item] = [:]
        for r in rows {
            guard let slot = EquipSlot(rawValue: r.slotRaw),
                  let ent = itemsById[r.itemId] else { continue }
            bySlot[slot] = ItemMapper.toRuntimeItem(ent)
        }
        return Equipment(bySlot: bySlot)
    }
}
#endif
