//
//  GameSaveModels.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData

@Model
public final class GameSaveEntity {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var createdAt: Date
    public var notes: String?
    public var gold: Int

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        notes: String? = nil,
        gold: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.notes = notes
        self.gold = max(0, gold)
    }
}

/// Snapshot of a party member at save-time (we do **not** rely on mutable global CharacterEntity).
@Model
public final class PartyMemberEntity {
    @Attribute(.unique) public var key: String     // "\(saveId)|\(position)"
    public var saveId: UUID
    public var position: Int                       // party order
    public var originalUUID: UUID                  // Character.id from runtime
    public var name: String
    public var stats: [Int]                        // aligned to CoreStat.allCases
    public var tags: [String]

    public init(saveId: UUID, position: Int, originalUUID: UUID, name: String, stats: [Int], tags: [String]) {
        self.saveId = saveId
        self.position = position
        self.originalUUID = originalUUID
        self.name = name
        self.stats = stats
        self.tags = tags
        self.key = "\(saveId.uuidString)|\(position)"
    }
}

/// Equipment rows **scoped to a save and a member**.
@Model
public final class SaveEquipmentSlotEntity {
    @Attribute(.unique) public var key: String    // "\(saveId)|\(memberUUID)|\(slot)"
    public var saveId: UUID
    public var memberUUID: UUID                    // original Character.id at save time
    public var slotRaw: String                     // EquipSlot.rawValue
    public var itemId: String

    public init(saveId: UUID, memberUUID: UUID, slotRaw: String, itemId: String) {
        self.saveId = saveId
        self.memberUUID = memberUUID
        self.slotRaw = slotRaw
        self.itemId = itemId
        self.key = "\(saveId.uuidString)|\(memberUUID.uuidString)|\(slotRaw)"
    }
}

/// Inventory rows **scoped to a save and a member** (simple item-id + quantity).
@Model
public final class SaveInventoryItemEntity {
    @Attribute(.unique) public var key: String    // "\(saveId)|\(memberUUID)|\(itemId)"
    public var saveId: UUID
    public var memberUUID: UUID
    public var itemId: String
    public var quantity: Int

    public init(saveId: UUID, memberUUID: UUID, itemId: String, quantity: Int) {
        self.saveId = saveId
        self.memberUUID = memberUUID
        self.itemId = itemId
        self.quantity = max(1, quantity)
        self.key = "\(saveId.uuidString)|\(memberUUID.uuidString)|\(itemId)"
    }
}
#endif
