//
//  ShopTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

import Testing
@testable import GameCore

@Suite struct ShopTests {

    @Test
    func buyWithSufficientGoldAndStock() throws {
        var inv = Inventory()
        var purse = GoldPurse(gold: 200)
        var shop = Shop(
            id: "s1",
            name: "Herbalist",
            offers: [
                ShopOffer(itemId: "herb", price: 25, stock: 10),
                ShopOffer(itemId: "gem",  price: 100, stock: 1),
            ]
        )

        let ev = try ShopEngine.buy(itemId: "herb", qty: 3, from: &shop, inventory: &inv, purse: &purse, timestamp: 1)
        #expect(purse.gold == 125)
        #expect(inv.quantity(of: "herb") == 3)
        #expect(shop.offers["herb"]?.stock == 7)
        #expect(ev.contains { $0.kind == .shopBuy && $0.data["itemId"] == "herb" && $0.data["qty"] == "3" })
    }

    @Test
    func buyFailsForOutOfStockOrNotEnoughGold() {
        var inv = Inventory()
        var purse = GoldPurse(gold: 40)
        var shop = Shop(
            id: "s1",
            name: "Herbalist",
            offers: [ShopOffer(itemId: "gem", price: 100, stock: 0)]
        )

        #expect(throws: ShopError.outOfStock(itemId: "gem")) {
            _ = try ShopEngine.buy(itemId: "gem", qty: 1, from: &shop, inventory: &inv, purse: &purse)
        }

        shop.offers["gem"] = ShopOffer(itemId: "gem", price: 100, stock: 1)
        #expect(throws: ShopError.notEnoughGold(needed: 100, have: 40)) {
            _ = try ShopEngine.buy(itemId: "gem", qty: 1, from: &shop, inventory: &inv, purse: &purse)
        }
    }

    @Test
    func sellPaysGoldAndOptionallyRestocksShop() throws {
        var inv = Inventory()
        inv.add(id: "herb", qty: 5)
        var purse = GoldPurse(gold: 0)
        var shop = Shop(
            id: "s1",
            name: "Herbalist",
            offers: [ShopOffer(itemId: "herb", price: 30, sellPrice: 12, stock: 2)]
        )

        let ev = try ShopEngine.sell(itemId: "herb", qty: 4, to: &shop, inventory: &inv, purse: &purse, timestamp: 2)
        #expect(purse.gold == 48)
        #expect(inv.quantity(of: "herb") == 1)
        #expect(shop.offers["herb"]?.stock == 6) // 2 + 4
        #expect(ev.contains { $0.kind == .shopSell && $0.data["itemId"] == "herb" && $0.data["qty"] == "4" })
    }

    @Test
    func sellFailsIfNotEnoughItems() {
        var inv = Inventory()
        var purse = GoldPurse(gold: 0)
        var shop = Shop(id: "s1", name: "Herbalist", offers: [ShopOffer(itemId: "herb", price: 20)])

        #expect(throws: ShopError.notEnoughItemsToSell(itemId: "herb", have: 0, want: 1)) {
            _ = try ShopEngine.sell(itemId: "herb", qty: 1, to: &shop, inventory: &inv, purse: &purse)
        }
    }
}
