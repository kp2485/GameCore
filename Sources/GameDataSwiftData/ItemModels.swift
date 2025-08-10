//
//  ItemModels.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData

public enum ItemKind: String, Codable, Sendable {
    case weapon, armor
}

/// Simple, explicit scaling schema we can persist (no closures).
public enum ScalingKind: String, Codable, Sendable {
    case none
    case strDivisor   // weapon damage adds (STR / divisor)
}

@Model
public final class ItemEntity {
    @Attribute(.unique) public var id: String
    public var name: String
    public var kind: String                      // ItemKind.rawValue
    public var tags: [String]

    // Weapon-only
    public var baseDamage: Int
    public var scalingKind: String               // ScalingKind.rawValue
    public var scalingParam: Int                 // e.g., divisor for strDivisor

    // Armor-only
    public var mitigationPercent: Int

    public init(
        id: String,
        name: String,
        kind: String,
        tags: [String],
        baseDamage: Int = 0,
        scalingKind: String = ScalingKind.none.rawValue,
        scalingParam: Int = 1,
        mitigationPercent: Int = 0
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.tags = tags
        self.baseDamage = baseDamage
        self.scalingKind = scalingKind
        self.scalingParam = scalingParam
        self.mitigationPercent = mitigationPercent
    }
}

/// One row per equipped slot for a character.
@Model
public final class EquipmentSlotEntity {
    @Attribute(.unique) public var key: String   // "\(characterUUID.uuidString)|\(slotRaw)"
    public var characterUUID: UUID
    public var slotRaw: String                   // EquipSlot.rawValue
    public var itemId: String

    public init(characterUUID: UUID, slotRaw: String, itemId: String) {
        self.characterUUID = characterUUID
        self.slotRaw = slotRaw
        self.itemId = itemId
        self.key = "\(characterUUID.uuidString)|\(slotRaw)"
    }
}
#endif
