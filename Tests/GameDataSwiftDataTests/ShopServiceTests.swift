//
//  ShopServiceTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

#if canImport(SwiftData)
import Testing
@testable import GameCore
@testable import GameDataSwiftData

@Suite @MainActor
struct ShopServiceTests {

    @Test
    func buyThenSellPersistsThroughRepositories() throws {
        // Stack + repos
        let stack    = try SDStack(inMemory: true)
        let saveRepo = SDGameSaveRepository(stack: stack)
        let shopRepo = SDShopRepository(stack: stack)

        // Seed a shop
        try shopRepo.upsertShop(
            Shop(
                id: "herbalist",
                name: "Herbalist",
                offers: [
                    ShopOffer(itemId: "herb", price: 25, stock: 10),
                    ShopOffer(itemId: "gem",  price: 100, sellPrice: 50, stock: 1)
                ]
            )
        )

        // Seed a save with one hero and gold
        let hero = Character(name: "Hero", stats: StatBlock([.hp: 30]))
        let provider = ClosureGameStateProvider(members: { [hero] })
        let saveSvc  = GameSaveService(repo: saveRepo, provider: provider)
        let saveId   = try saveSvc.saveCurrentGame(name: "S1")
        try saveRepo.addGold(saveId: saveId, amount: 200)

        let svc = ShopService(shopRepo: shopRepo, saveRepo: saveRepo)

        // BUY 3 herbs into first party member (hero)
        let buyEv = try svc.buy(shopId: "herbalist", saveId: saveId, itemId: "herb", qty: 3)
        #expect(buyEv.contains { $0.kind == .shopBuy && $0.data["itemId"] == "herb" && $0.data["qty"] == "3" })

        // Gold decreased; inventory shows items
        #expect(try saveRepo.currentGold(saveId: saveId) == 125)
        let afterBuy = try saveSvc.loadGame(id: saveId)
        let bag = afterBuy.inventoriesById[hero.id] ?? [:]
        #expect(bag["herb"] == 3)

        // SELL 2 herbs back
        let sellEv = try svc.sell(shopId: "herbalist", saveId: saveId, itemId: "herb", qty: 2, fromMember: hero.id)
        #expect(sellEv.contains { $0.kind == .shopSell && $0.data["itemId"] == "herb" && $0.data["qty"] == "2" })

        // Gold increased by sell revenue; inventory decreased accordingly
        // sellPrice default is 50% of buy price (25 -> 12 each, truncating)
        let goldNow = try saveRepo.currentGold(saveId: saveId)
        #expect(goldNow == 125 + 12 * 2)

        let afterSell = try saveSvc.loadGame(id: saveId)
        let bag2 = afterSell.inventoriesById[hero.id] ?? [:]
        #expect(bag2["herb"] == 1)

        // Shop stock updated (10 -> 7 after buy; then +2 after sell if tracked)
        let snap = try shopRepo.loadShop(id: "herbalist")!
        let offers = Dictionary(uniqueKeysWithValues: snap.offers.map { ($0.itemId, $0) })
        #expect(offers["herb"]?.stock == 9) // start 10 -> buy 3 => 7 -> sell 2 => 9
    }
}
#endif
