//
//  ShopService.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//


#if canImport(SwiftData)
import Foundation
import GameCore

@MainActor
public final class ShopService: Sendable {
    private let shopRepo: SDShopRepository
    private let saveRepo: SDGameSaveRepository

    public init(shopRepo: SDShopRepository, saveRepo: SDGameSaveRepository) {
        self.shopRepo = shopRepo
        self.saveRepo = saveRepo
    }

    /// Load a shop for display.
    public func loadShop(id: String) throws -> ShopSnapshot? {
        try shopRepo.loadShop(id: id)
    }

    /// Buy items into a save’s first party member (or a specific member).
    /// Returns events for UI/logging.
    public func buy(
        shopId: String,
        saveId: UUID,
        itemId: String,
        qty: Int,
        toMember target: UUID? = nil,
        timestamp: UInt64 = 0
    ) throws -> [Event] {
        guard qty > 0 else { return [] }
        guard let snapshot = try shopRepo.loadShop(id: shopId) else { return [] }
        var shop = Shop(id: snapshot.id, name: snapshot.name, offers: snapshot.offers)

        // Decide member
        let memberIds = try saveRepo.orderedMemberUUIDs(saveId: saveId)
        guard let receiver = target ?? memberIds.first else { return [] }

        // Pull purse
        let currentGold = try saveRepo.currentGold(saveId: saveId)
        var purse = GoldPurse(gold: currentGold)
        var inv = Inventory()
        // prime with existing member bag
        let loaded = try saveRepo.loadSave(id: saveId)
        if let bag = loaded.inventoriesById[receiver] {
            for (id, q) in bag { inv.add(id: id, qty: q) }
        }

        // transact via core engine
        let ev = try ShopEngine.buy(itemId: itemId, qty: qty, from: &shop, inventory: &inv, purse: &purse, timestamp: timestamp)

        // persist updates
        let delta = purse.gold - currentGold          // e.g. 125 - 200 = -75
        try saveRepo.adjustGold(saveId: saveId, delta: delta)
        try saveRepo.addItems(saveId: saveId, memberUUID: receiver, items: [itemId: qty])
        // persist stock
        let newStock = shop.offers[itemId]?.stock
        try shopRepo.updateOfferStock(shopId: shopId, itemId: itemId, newStock: newStock)

        return ev
    }

    /// Sell items from a save’s member inventory.
    public func sell(
        shopId: String,
        saveId: UUID,
        itemId: String,
        qty: Int,
        fromMember source: UUID,
        timestamp: UInt64 = 0
    ) throws -> [Event] {
        guard qty > 0 else { return [] }
        guard let snapshot = try shopRepo.loadShop(id: shopId) else { return [] }
        var shop = Shop(id: snapshot.id, name: snapshot.name, offers: snapshot.offers)

        // Load current bag + purse
        let currentGold = try saveRepo.currentGold(saveId: saveId)
        var purse = GoldPurse(gold: currentGold)

        let loaded = try saveRepo.loadSave(id: saveId)
        let bag = loaded.inventoriesById[source] ?? [:]
        var inv = Inventory()
        for (id, q) in bag { inv.add(id: id, qty: q) }

        // transact
        let ev = try ShopEngine.sell(itemId: itemId, qty: qty, to: &shop, inventory: &inv, purse: &purse, timestamp: timestamp)

        // persist: gold delta
        let delta2 = purse.gold - currentGold         // e.g. 149 - 125 = +24
        try saveRepo.adjustGold(saveId: saveId, delta: delta2)

        // compute new bag map
        var newMap: [String:Int] = [:]
        for s in inv.all { newMap[s.itemId] = s.qty }

        // Replace rows:
        try saveRepo.setItems(saveId: saveId, memberUUID: source, map: newMap)

        // persist stock
        let newStock = shop.offers[itemId]?.stock
        try shopRepo.updateOfferStock(shopId: shopId, itemId: itemId, newStock: newStock)

        return ev
    }
}
#endif
