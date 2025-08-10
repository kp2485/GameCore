//
//  Items.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public protocol Item: Sendable {
    var id: String { get }
    var name: String { get }
    var tags: Set<String> { get }   // e.g. "blade", "light", "robe"
}

/// Weapons are equatable/hashable by **id** only (ignore the closure).
public struct Weapon: Item, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let tags: Set<String>
    /// Base damage before scaling.
    public let baseDamage: Int
    /// Optional stat scaling; ignored for Equatable/Hashable (identity is `id`).
    public let scale: @Sendable (Character) -> Int

    public init(
        id: String,
        name: String,
        tags: Set<String>,
        baseDamage: Int,
        scale: @escaping @Sendable (Character) -> Int = { _ in 0 }
    ) {
        self.id = id
        self.name = name
        self.tags = tags
        self.baseDamage = baseDamage
        self.scale = scale
    }

    public static func == (lhs: Weapon, rhs: Weapon) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Armor is equatable/hashable by **id** only.
public struct Armor: Item, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let tags: Set<String>
    /// Flat mitigation percent (0…100)
    public let mitigationPercent: Int

    public init(id: String, name: String, tags: Set<String>, mitigationPercent: Int) {
        self.id = id
        self.name = name
        self.tags = tags
        self.mitigationPercent = max(0, min(100, mitigationPercent))
    }

    public static func == (lhs: Armor, rhs: Armor) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public enum ItemError: Error, CustomStringConvertible, Sendable {
    case slotOccupied(EquipSlot)
    case slotEmpty(EquipSlot)
    case notAllowed(String)      // reason
    case notFound(String)        // item id

    public var description: String {
        switch self {
        case .slotOccupied(let s): return "Slot \(s) is occupied"
        case .slotEmpty(let s):    return "Slot \(s) is empty"
        case .notAllowed(let r):   return "Not allowed: \(r)"
        case .notFound(let id):    return "Item not found: \(id)"
        }
    }
}
