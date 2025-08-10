//
//  Equipment.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public enum EquipSlot: String, CaseIterable, Sendable, Hashable {
    case mainHand, offHand, head, body, hands, feet, accessory
}

/// Current worn/wielded items. Equatable/Hashable are implemented
/// by comparing **item IDs by slot** (not the existential values).
public struct Equipment: Sendable, Equatable, Hashable {
    public var bySlot: [EquipSlot: any Item] = [:]

    public init(bySlot: [EquipSlot: any Item] = [:]) {
        self.bySlot = bySlot
    }

    public func item(in slot: EquipSlot) -> (any Item)? { bySlot[slot] }

    public mutating func equip(_ item: any Item, to slot: EquipSlot) throws {
        if bySlot[slot] != nil { throw ItemError.slotOccupied(slot) }
        bySlot[slot] = item
    }

    public mutating func unequip(from slot: EquipSlot) throws -> (any Item) {
        guard let old = bySlot.removeValue(forKey: slot) else { throw ItemError.slotEmpty(slot) }
        return old
    }

    // MARK: Equatable/Hashable via IDs

    public static func == (lhs: Equipment, rhs: Equipment) -> Bool {
        lhs.slotIdMap == rhs.slotIdMap
    }

    public func hash(into hasher: inout Hasher) {
        // Stable order: sort by slot rawValue
        for (slot, id) in slotIdMap.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            hasher.combine(slot)
            hasher.combine(id)
        }
    }

    private var slotIdMap: [EquipSlot: String] {
        var out: [EquipSlot: String] = [:]
        for (slot, item) in bySlot {
            out[slot] = item.id
        }
        return out
    }
}

/// Inventory + equipment for one character. Equatable/Hashable compare **IDs**.
public struct Loadout: Sendable, Equatable, Hashable {
    public var inventory: [String: any Item]     // keyed by id
    public var equipment: Equipment

    public init(inventory: [any Item] = [], equipment: Equipment = Equipment()) {
        self.inventory = Dictionary(uniqueKeysWithValues: inventory.map { ($0.id, $0) })
        self.equipment = equipment
    }

    public func has(_ id: String) -> Bool { inventory[id] != nil }

    public mutating func add(_ item: any Item) {
        inventory[item.id] = item
    }

    public mutating func remove(_ id: String) throws -> (any Item) {
        guard let it = inventory.removeValue(forKey: id) else { throw ItemError.notFound(id) }
        return it
    }

    /// Equip from inventory to slot after simple legality checks.
    public mutating func equip(
        itemId: String,
        to slot: EquipSlot,
        for character: Character,
        classDef: ClassDef
    ) throws {
        guard let item = inventory[itemId] else { throw ItemError.notFound(itemId) }
        if let w = item as? Weapon {
            guard !classDef.allowedWeapons.isEmpty else { throw ItemError.notAllowed("no weapons allowed for class") }
            guard !classDef.allowedWeapons.isDisjoint(with: w.tags) else {
                throw ItemError.notAllowed("weapon tag not permitted")
            }
        }
        if let a = item as? Armor {
            guard !classDef.allowedArmor.isEmpty else { throw ItemError.notAllowed("no armor allowed for class") }
            guard !classDef.allowedArmor.isDisjoint(with: a.tags) else {
                throw ItemError.notAllowed("armor tag not permitted")
            }
        }
        try equipment.equip(item, to: slot)
    }

    // MARK: Equatable/Hashable via IDs

    public static func == (lhs: Loadout, rhs: Loadout) -> Bool {
        lhs.inventory.keys.sorted() == rhs.inventory.keys.sorted()
        && lhs.equipment == rhs.equipment
    }

    public func hash(into hasher: inout Hasher) {
        for id in inventory.keys.sorted() { hasher.combine(id) }
        hasher.combine(equipment)
    }
}

/// Combat helpers that operate on Equipment values
public enum EquipmentMath: Sendable {
    /// Sum armor mitigation (cap at 80%).
    public static func mitigationPercent(from eq: Equipment) -> Int {
        let pct = eq.bySlot.values.compactMap { ($0 as? Armor)?.mitigationPercent }.reduce(0, +)
        return min(80, pct)
    }

    /// Compute weapon damage contribution (base + scaling) for main/off hand.
    public static func weaponDamage(for c: Character, eq: Equipment) -> Int {
        var dmg = 0
        if let w = eq.item(in: .mainHand) as? Weapon {
            dmg += w.baseDamage + w.scale(c)
        }
        if let w = eq.item(in: .offHand) as? Weapon {
            dmg += max(0, (w.baseDamage + w.scale(c)) / 2) // offhand penalty
        }
        return dmg
    }
}
