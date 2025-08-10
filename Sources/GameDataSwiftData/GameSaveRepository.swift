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

public struct GameSaveMeta: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
}

/// Public API for saving/loading a party snapshot.
@MainActor
public protocol GameSaveRepository: Sendable {
    func saveGame(name: String,
                  members: [Character],
                  equipmentById: [UUID: Equipment],
                  inventoriesById: [UUID: [String: Int]],
                  notes: String?) throws -> UUID

    func loadSave(id: UUID) throws -> (members: [Character],
                                       equipmentById: [UUID: Equipment],
                                       inventoriesById: [UUID: [String: Int]],
                                       meta: GameSaveMeta)

    func loadLatest() throws -> UUID?
    func listSaves() throws -> [GameSaveMeta]
    func deleteSave(id: UUID) throws
}

@MainActor
public final class SDGameSaveRepository: GameSaveRepository {
    private let stack: SDStack
    public init(stack: SDStack) { self.stack = stack }

    public func saveGame(name: String,
                         members: [Character],
                         equipmentById: [UUID: Equipment],
                         inventoriesById: [UUID: [String: Int]],
                         notes: String?) throws -> UUID {
        let ctx = stack.context
        let save = GameSaveEntity(name: name, notes: notes)
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
                for (itemId, qty) in inv {
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

    public func loadSave(id: UUID) throws -> (members: [Character],
                                              equipmentById: [UUID: Equipment],
                                              inventoriesById: [UUID: [String: Int]],
                                              meta: GameSaveMeta) {
        let ctx = stack.context

        // Save meta
        let sid = id
        var saveFd = FetchDescriptor<GameSaveEntity>(predicate: #Predicate { $0.id == sid })
        saveFd.fetchLimit = 1
        guard let save = try ctx.fetch(saveFd).first else { throw SwiftDataError.missingRecord }
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
        var fd = FetchDescriptor<GameSaveEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        fd.fetchLimit = 1
        return try ctx.fetch(fd).first?.id
    }

    public func listSaves() throws -> [GameSaveMeta] {
        let ctx = stack.context
        let fd = FetchDescriptor<GameSaveEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try ctx.fetch(fd).map { GameSaveMeta(id: $0.id, name: $0.name, createdAt: $0.createdAt) }
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
#endif
