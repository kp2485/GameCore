//
//  ShopRepository.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData
import GameCore

/// A plain snapshot of a shop (for UI / services).
public struct ShopSnapshot: Sendable, Equatable {
    public var id: String
    public var name: String
    public var offers: [ShopOffer]   // from GameCore

    public init(id: String, name: String, offers: [ShopOffer]) {
        self.id = id
        self.name = name
        self.offers = offers
    }
}

/// SwiftData-backed repository for shops.
@MainActor
public final class SDShopRepository: Sendable {
    let stack: SDStack

    public init(stack: SDStack) { self.stack = stack }

    /// Create or update a shop and all of its offers from a core `Shop` model.
    public func upsertShop(_ shop: Shop) throws {
        let ctx = stack.context

        // Capture scalars for #Predicate (avoids macro type issues)
        let shopId = shop.id

        // Upsert ShopEntity
        var sfd = FetchDescriptor<ShopEntity>(predicate: #Predicate { $0.id == shopId })
        sfd.fetchLimit = 1
        let shopRow: ShopEntity
        if let existing = try ctx.fetch(sfd).first {
            shopRow = existing
            shopRow.name = shop.name
        } else {
            shopRow = ShopEntity(id: shop.id, name: shop.name)
            ctx.insert(shopRow)
        }

        // Fetch current offers for this shop
        let ofd = FetchDescriptor<ShopOfferEntity>(predicate: #Predicate { $0.shopId == shopId })
        let existingOffers = try ctx.fetch(ofd)
        let existingByItem = Dictionary(uniqueKeysWithValues: existingOffers.map { ($0.itemId, $0) })

        // Upsert each offer from core
        for offer in shop.offers.values {
            if let row = existingByItem[offer.itemId] {
                row.price = offer.price
                row.sellPrice = offer.sellPrice
                row.stock = offer.stock
            } else {
                let row = ShopOfferEntity(
                    shopId: shop.id,
                    itemId: offer.itemId,
                    price: offer.price,
                    sellPrice: offer.sellPrice,
                    stock: offer.stock
                )
                ctx.insert(row)
            }
        }

        try ctx.save()
    }

    /// Load a shop snapshot by id (nil if it doesn't exist).
    public func loadShop(id: String) throws -> ShopSnapshot? {
        let ctx = stack.context
        let sid = id

        var sfd = FetchDescriptor<ShopEntity>(predicate: #Predicate { $0.id == sid })
        sfd.fetchLimit = 1
        guard let s = try ctx.fetch(sfd).first else { return nil }

        let ofd = FetchDescriptor<ShopOfferEntity>(predicate: #Predicate { $0.shopId == sid })
        let rows = try ctx.fetch(ofd)

        let offers = rows.map {
            ShopOffer(itemId: $0.itemId, price: $0.price, sellPrice: $0.sellPrice, stock: $0.stock)
        }

        return ShopSnapshot(id: s.id, name: s.name, offers: offers)
    }

    /// Update stock count for a single offer (nil = infinite).
    public func updateOfferStock(shopId: String, itemId: String, newStock: Int?) throws {
        let ctx = stack.context
        let sid = shopId
        let iid = itemId

        var ofd = FetchDescriptor<ShopOfferEntity>(
            predicate: #Predicate { $0.shopId == sid && $0.itemId == iid }
        )
        ofd.fetchLimit = 1
        guard let row = try ctx.fetch(ofd).first else { return }
        row.stock = newStock
        try ctx.save()
    }
}
#endif
