//
//  Rewards.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// Minimal stack for stackable items by id (data-driven later via Items DB).
public struct ItemStack: Sendable, Equatable, Hashable {
    public var itemId: String
    public var qty: Int
    public init(_ itemId: String, _ qty: Int) { self.itemId = itemId; self.qty = max(0, qty) }
}

public struct Inventory: Sendable, Equatable {
    // simple map; for UI you can sort/group later
    public private(set) var stacks: [String: Int] = [:]
    public init() {}
    public mutating func add(id: String, qty: Int) {
        guard qty > 0 else { return }
        stacks[id, default: 0] &+= qty
    }
    public mutating func remove(id: String, qty: Int) -> Bool {
        guard qty > 0, let cur = stacks[id], cur >= qty else { return false }
        let nxt = cur - qty
        if nxt == 0 { stacks.removeValue(forKey: id) } else { stacks[id] = nxt }
        return true
    }
    public func quantity(of id: String) -> Int { stacks[id] ?? 0 }
    public var all: [ItemStack] { stacks.map { ItemStack($0.key, $0.value) } }
}

public struct GoldPurse: Sendable, Equatable {
    public private(set) var gold: Int = 0
    public init(gold: Int = 0) { self.gold = max(0, gold) }
    public mutating func add(_ amount: Int) { gold = max(0, gold &+ max(0, amount)) }
    public mutating func spend(_ amount: Int) -> Bool {
        guard amount >= 0, gold >= amount else { return false }
        gold -= amount
        return true
    }
}

// Fold battle events into a summary the app layer can apply/persist.
public struct RewardSummary: Sendable, Equatable {
    public var totalXP: Int = 0
    public var gold: Int = 0
    public var loot: [ItemStack] = []
    public var levelUps: [String: Int] = [:] // actor name -> times leveled (display helper)

    public init() {}

    public static func from(events: [Event]) -> RewardSummary {
        var sum = RewardSummary()
        for e in events {
            switch e.kind {
            case .xpGained:
                if let amt = Int(e.data["amount"] ?? "0") { sum.totalXP &+= amt }
            case .levelUp:
                if let who = e.data["actor"] {
                    sum.levelUps[who, default: 0] &+= 1
                }
            case .goldAwarded:
                if let amt = Int(e.data["amount"] ?? "0") { sum.gold &+= amt }
            case .lootDropped:
                if let id = e.data["itemId"], let qty = Int(e.data["qty"] ?? "0"), qty > 0 {
                    // collapse duplicates into one stack
                    if let i = sum.loot.firstIndex(where: { $0.itemId == id }) {
                        sum.loot[i].qty &+= qty
                    } else {
                        sum.loot.append(ItemStack(id, qty))
                    }
                }
            default:
                continue
            }
        }
        return sum
    }
}

// Apply reward summary to a party state (inventory + purse).
public struct PartyRewardsApplier: Sendable {
    public init() {}
    public mutating func apply(_ rewards: RewardSummary,
                               to inventory: inout Inventory,
                               purse: inout GoldPurse) {
        purse.add(rewards.gold)
        for s in rewards.loot {
            inventory.add(id: s.itemId, qty: s.qty)
        }
        // XP and level ups are already applied in-combat by the battle loop’s award step.
    }
}
