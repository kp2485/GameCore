//
//  Shop.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

import Foundation

public struct ShopOffer: Sendable, Equatable, Hashable {
    public let itemId: String
    public var price: Int              // per-unit price (buy price)
    public var sellPrice: Int?         // optional per-unit sell price (default: 50% of price)
    public var stock: Int?             // nil = infinite
    public init(itemId: String, price: Int, sellPrice: Int? = nil, stock: Int? = nil) {
        precondition(price >= 0)
        if let s = sellPrice { precondition(s >= 0) }
        if let s = stock { precondition(s >= 0) }
        self.itemId = itemId
        self.price = price
        self.sellPrice = sellPrice
        self.stock = stock
    }
}

public struct Shop: Sendable, Equatable {
    public var id: String
    public var name: String
    public var offers: [String: ShopOffer]   // keyed by itemId
    public init(id: String, name: String, offers: [ShopOffer]) {
        self.id = id; self.name = name
        self.offers = Dictionary(uniqueKeysWithValues: offers.map { ($0.itemId, $0) })
    }
}

public enum ShopError: Error, Sendable, Equatable {
    case missingOffer(itemId: String)
    case outOfStock(itemId: String)
    case notEnoughGold(needed: Int, have: Int)
    case notEnoughItemsToSell(itemId: String, have: Int, want: Int)
    case invalidQuantity
}

/// Engine performing buy/sell, emitting events and updating inventory/purse/stock.
public enum ShopEngine {
    @discardableResult
    public static func buy(
        itemId: String,
        qty: Int,
        from shop: inout Shop,
        inventory: inout Inventory,
        purse: inout GoldPurse,
        timestamp: UInt64 = 0
    ) throws -> [Event] {
        guard qty > 0 else { throw ShopError.invalidQuantity }
        guard var offer = shop.offers[itemId] else { throw ShopError.missingOffer(itemId: itemId) }

        // Stock check
        if let s = offer.stock, s < qty { throw ShopError.outOfStock(itemId: itemId) }

        // Cost
        let cost = offer.price * qty
        let have = purse.gold
        guard have >= cost else { throw ShopError.notEnoughGold(needed: cost, have: have) }

        // Apply
        _ = purse.spend(cost)
        inventory.add(id: itemId, qty: qty)
        if let s = offer.stock { offer.stock = s - qty }
        shop.offers[itemId] = offer

        return [
            Event(kind: .shopBuy, timestamp: timestamp, data: [
                "shopId": shop.id, "itemId": itemId, "qty": String(qty), "cost": String(cost)
            ])
        ]
    }

    @discardableResult
    public static func sell(
        itemId: String,
        qty: Int,
        to shop: inout Shop,
        inventory: inout Inventory,
        purse: inout GoldPurse,
        timestamp: UInt64 = 0
    ) throws -> [Event] {
        guard qty > 0 else { throw ShopError.invalidQuantity }
        guard let offer = shop.offers[itemId] else { throw ShopError.missingOffer(itemId: itemId) }

        let have = inventory.quantity(of: itemId)
        guard have >= qty else { throw ShopError.notEnoughItemsToSell(itemId: itemId, have: have, want: qty) }

        let unit = offer.sellPrice ?? (offer.price / 2)
        let revenue = unit * qty

        // Apply
        _ = inventory.remove(id: itemId, qty: qty)
        purse.add(revenue)

        // If shop tracks stock, increase it on sell
        if var sOffer = shop.offers[itemId], let s = sOffer.stock {
            sOffer.stock = s + qty
            shop.offers[itemId] = sOffer
        }

        return [
            Event(kind: .shopSell, timestamp: timestamp, data: [
                "shopId": shop.id, "itemId": itemId, "qty": String(qty), "revenue": String(revenue)
            ])
        ]
    }
}
