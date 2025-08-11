//
//  ShopRepositoryTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

#if canImport(SwiftData)
import Testing
@testable import GameCore
@testable import GameDataSwiftData

@Suite @MainActor
struct ShopRepositoryTests {

    @Test
    func upsertAndLoadShopRoundTrip() throws {
        let stack = try SDStack(inMemory: true)
        let repo  = SDShopRepository(stack: stack)

        // Seed a core Shop
        let core = Shop(
            id: "herbalist",
            name: "Herbalist",
            offers: [
                ShopOffer(itemId: "herb", price: 25, stock: 10),
                ShopOffer(itemId: "gem",  price: 100, sellPrice: 50, stock: 1)
            ]
        )

        try repo.upsertShop(core)
        guard let snap = try repo.loadShop(id: "herbalist") else {
            Issue.record("Expected shop snapshot")
            return
        }

        #expect(snap.id == "herbalist")
        #expect(snap.name == "Herbalist")

        // Turn offers into a map for easy assertions
        let offersById = Dictionary(uniqueKeysWithValues: snap.offers.map { ($0.itemId, $0) })
        #expect(offersById["herb"]?.price == 25)
        #expect(offersById["herb"]?.stock == 10)
        #expect(offersById["gem"]?.price == 100)
        #expect(offersById["gem"]?.sellPrice == 50)
        #expect(offersById["gem"]?.stock == 1)

        // Update stock and verify
        try repo.updateOfferStock(shopId: "herbalist", itemId: "herb", newStock: 7)
        let snap2 = try repo.loadShop(id: "herbalist")!
        let herb2 = Dictionary(uniqueKeysWithValues: snap2.offers.map { ($0.itemId, $0) })["herb"]
        #expect(herb2?.stock == 7)
    }
}
#endif
