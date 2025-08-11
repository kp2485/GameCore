//
//  GameSaveRepository.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData
import GameCore

// MARK: - Meta DTO

public struct GameSaveMeta: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
}

// MARK: - Public API

@MainActor
public protocol GameSaveRepository: Sendable {
    func saveGame(
        name: String,
        members: [Character],
        equipmentById: [UUID: Equipment],
        inventoriesById: [UUID: [String: Int]],
        notes: String?
    ) throws -> UUID

    func loadSave(
        id: UUID
    ) throws -> (
        members: [Character],
        equipmentById: [UUID: Equipment],
        inventoriesById: [UUID: [String: Int]],
        meta: GameSaveMeta
    )

    func loadLatest() throws -> UUID?
    func listSaves() throws -> [GameSaveMeta]
    func deleteSave(id: UUID) throws
}

// MARK: - SwiftData-backed implementation

@MainActor
public final class SDGameSaveRepository: GameSaveRepository {
    let stack: SDStack
    public init(stack: SDStack) { self.stack = stack }

    // MARK: Create

    public func saveGame(
        name: String,
        members: [Character],
        equipmentById: [UUID: Equipment],
        inventoriesById: [UUID: [String: Int]],
        notes: String?
    ) throws -> UUID {
        let ctx = stack.context
        let save = GameSaveEntity(name: name, notes: notes) // gold defaults to 0
        ctx.insert(save)

        for (idx, m) in members.enumerated() {
            ctx.insert(PartyMemberEntity(
                saveId: save.id,
                position: idx,
                originalUUID: m.id,
                name: m.name,
                stats: StatsCodec.encode(m.stats),
                tags: Array(m.tags)
            ))

            if let eq = equipmentById[m.id] {
                for (slot, item) in eq.bySlot {
                    ctx.insert(SaveEquipmentSlotEntity(
                        saveId: save.id,
                        memberUUID: m.id,
                        slotRaw: slot.rawValue,
                        itemId: item.id
                    ))
                }
            }

            if let inv = inventoriesById[m.id] {
                for (itemId, qty) in inv where qty > 0 {
                    ctx.insert(SaveInventoryItemEntity(
                        saveId: save.id,
                        memberUUID: m.id,
                        itemId: itemId,
                        quantity: qty
                    ))
                }
            }
        }

        try ctx.save()
        return save.id
    }

    // MARK: Read

    public func loadSave(
        id: UUID
    ) throws -> (
        members: [Character],
        equipmentById: [UUID: Equipment],
        inventoriesById: [UUID: [String: Int]],
        meta: GameSaveMeta
    ) {
        let ctx = stack.context
        let sid = id

        // Save meta
        var saveFd = FetchDescriptor<GameSaveEntity>(predicate: #Predicate { $0.id == sid })
        saveFd.fetchLimit = 1
        guard let save = try ctx.fetch(saveFd).first else {
            throw SwiftDataError.missingRecord
        }
        let meta = GameSaveMeta(id: save.id, name: save.name, createdAt: save.createdAt)

        // Members (ordered)
        let memberFd = FetchDescriptor<PartyMemberEntity>(
            predicate: #Predicate { $0.saveId == sid },
            sortBy: [SortDescriptor(\.position, order: .forward)]
        )
        let memberRows = try ctx.fetch(memberFd)

        let members: [Character] = memberRows.map {
            Character(name: $0.name, stats: StatsCodec.decode($0.stats), tags: Set($0.tags))
        }

        // Equipment
        var equipmentById: [UUID: Equipment] = [:]
        let memberUUIDs = Set(memberRows.map { $0.originalUUID })
        let uuids = Array(memberUUIDs)

        let slotFd = FetchDescriptor<SaveEquipmentSlotEntity>(
            predicate: #Predicate { $0.saveId == sid && uuids.contains($0.memberUUID) }
        )
        let slotRows = try ctx.fetch(slotFd)

        let itemIds = Set(slotRows.map { $0.itemId })
        var itemMap: [String: ItemEntity] = [:]
        if !itemIds.isEmpty {
            let ids = Array(itemIds)
            var itemFd = FetchDescriptor<ItemEntity>(predicate: #Predicate { ids.contains($0.id) })
            itemFd.sortBy = [SortDescriptor(\.id)]
            let items = try ctx.fetch(itemFd)
            itemMap = items.reduce(into: [:]) { $0[$1.id] = $1 }
        }

        for uuid in memberUUIDs {
            var bySlot: [EquipSlot: any Item] = [:]
            for row in slotRows where row.memberUUID == uuid {
                guard let slot = EquipSlot(rawValue: row.slotRaw),
                      let ent  = itemMap[row.itemId] else { continue }
                bySlot[slot] = ItemMapper.toRuntimeItem(ent)
            }
            if !bySlot.isEmpty { equipmentById[uuid] = Equipment(bySlot: bySlot) }
        }

        // Inventories
        var inventoriesById: [UUID: [String: Int]] = [:]
        let invFd = FetchDescriptor<SaveInventoryItemEntity>(predicate: #Predicate { $0.saveId == sid })
        let invRows = try ctx.fetch(invFd)
        for row in invRows {
            inventoriesById[row.memberUUID, default: [:]][row.itemId] = row.quantity
        }

        return (members, equipmentById, inventoriesById, meta)
    }

    public func loadLatest() throws -> UUID? {
        let ctx = stack.context
        var fd = FetchDescriptor<GameSaveEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        fd.fetchLimit = 1
        return try ctx.fetch(fd).first?.id
    }

    public func listSaves() throws -> [GameSaveMeta] {
        let ctx = stack.context
        let fd = FetchDescriptor<GameSaveEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try ctx.fetch(fd).map {
            GameSaveMeta(id: $0.id, name: $0.name, createdAt: $0.createdAt)
        }
    }

    public func deleteSave(id: UUID) throws {
        let ctx = stack.context
        let sid = id

        let delSlots = FetchDescriptor<SaveEquipmentSlotEntity>(predicate: #Predicate { $0.saveId == sid })
        for row in try ctx.fetch(delSlots) { ctx.delete(row) }

        let delInv = FetchDescriptor<SaveInventoryItemEntity>(predicate: #Predicate { $0.saveId == sid })
        for row in try ctx.fetch(delInv) { ctx.delete(row) }

        let delMembers = FetchDescriptor<PartyMemberEntity>(predicate: #Predicate { $0.saveId == sid })
        for row in try ctx.fetch(delMembers) { ctx.delete(row) }

        var saveFd = FetchDescriptor<GameSaveEntity>(predicate: #Predicate { $0.id == sid })
        saveFd.fetchLimit = 1
        if let s = try ctx.fetch(saveFd).first { ctx.delete(s) }

        try ctx.save()
    }
}

// MARK: - Convenience Queries / Mutations

@MainActor
public extension SDGameSaveRepository {
    /// Current save gold (stored on GameSaveEntity.gold).
    func currentGold(saveId: UUID) throws -> Int {
        let ctx = stack.context
        let sid = saveId
        var fd = FetchDescriptor<GameSaveEntity>(predicate: #Predicate { $0.id == sid })
        fd.fetchLimit = 1
        guard let row = try ctx.fetch(fd).first else { throw SwiftDataError.missingRecord }
        return max(0, row.gold)
    }

    /// Set absolute gold amount (clamped at 0).
    func setGold(saveId: UUID, to amount: Int) throws {
        let ctx = stack.context
        let sid = saveId
        var fd = FetchDescriptor<GameSaveEntity>(predicate: #Predicate { $0.id == sid })
        fd.fetchLimit = 1
        guard let row = try ctx.fetch(fd).first else { throw SwiftDataError.missingRecord }
        row.gold = max(0, amount)
        try ctx.save()
    }

    /// Add (positive) gold.
    func addGold(saveId: UUID, amount: Int) throws {
        guard amount > 0 else { return }
        let cur = try currentGold(saveId: saveId)
        try setGold(saveId: saveId, to: cur &+ amount)
    }

    /// Spend (subtract) gold, clamped at zero.
    func spendGold(saveId: UUID, amount: Int) throws {
        guard amount > 0 else { return }
        let cur = try currentGold(saveId: saveId)
        try setGold(saveId: saveId, to: max(0, cur &- amount))
    }

    /// Adjust by signed delta (+/-).
    func adjustGold(saveId: UUID, delta: Int) throws {
        if delta == 0 { return }
        if delta > 0 { try addGold(saveId: saveId, amount: delta) }
        else          { try spendGold(saveId: saveId, amount: -delta) }
    }

    /// Member UUIDs in party order.
    func orderedMemberUUIDs(saveId: UUID) throws -> [UUID] {
        let ctx = stack.context
        let sid = saveId
        let fd = FetchDescriptor<PartyMemberEntity>(
            predicate: #Predicate { $0.saveId == sid },
            sortBy: [SortDescriptor(\.position, order: .forward)]
        )
        return try ctx.fetch(fd).map { $0.originalUUID }
    }

    /// Upsert (add) items to a specific member’s bag.
    func addItems(saveId: UUID, memberUUID: UUID, items: [String:Int]) throws {
        guard !items.isEmpty else { return }
        let ctx = stack.context
        let sid = saveId
        let mid = memberUUID

        // Fetch existing rows for the member
        let invFd = FetchDescriptor<SaveInventoryItemEntity>(
            predicate: #Predicate { $0.saveId == sid && $0.memberUUID == mid }
        )
        let rows = try ctx.fetch(invFd)
        var byId: [String: SaveInventoryItemEntity] = [:]
        for r in rows { byId[r.itemId] = r }

        for (itemId, delta) in items where delta > 0 {
            if let existing = byId[itemId] {
                existing.quantity = max(1, existing.quantity &+ delta)
            } else {
                ctx.insert(SaveInventoryItemEntity(
                    saveId: sid,
                    memberUUID: mid,
                    itemId: itemId,
                    quantity: delta
                ))
            }
        }
        try ctx.save()
    }

    /// Replace a member’s bag with an exact map (itemId -> qty). Deletes rows for zero/negative.
    func setItems(saveId: UUID, memberUUID: UUID, map: [String:Int]) throws {
        let ctx = stack.context
        let sid = saveId
        let mid = memberUUID

        let delFd = FetchDescriptor<SaveInventoryItemEntity>(
            predicate: #Predicate { $0.saveId == sid && $0.memberUUID == mid }
        )
        for row in try ctx.fetch(delFd) { ctx.delete(row) }

        for (itemId, qty) in map where qty > 0 {
            ctx.insert(SaveInventoryItemEntity(
                saveId: sid,
                memberUUID: mid,
                itemId: itemId,
                quantity: qty
            ))
        }
        try ctx.save()
    }
}
#endif
