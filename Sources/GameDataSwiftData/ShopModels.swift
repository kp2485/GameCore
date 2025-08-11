//
//  ShopModels.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData

@Model
public final class ShopEntity {
    @Attribute(.unique) public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// One row per item the shop trades in.
@Model
public final class ShopOfferEntity {
    @Attribute(.unique) public var key: String   // "\(shopId)|\(itemId)"
    public var shopId: String
    public var itemId: String
    public var price: Int             // buy price
    public var sellPrice: Int?        // optional explicit sell price
    public var stock: Int?            // nil = infinite

    public init(shopId: String, itemId: String, price: Int, sellPrice: Int? = nil, stock: Int? = nil) {
        self.shopId = shopId
        self.itemId = itemId
        self.price = max(0, price)
        self.sellPrice = sellPrice.map { max(0, $0) }
        self.stock = stock
        self.key = "\(shopId)|\(itemId)"
    }
}
#endif
