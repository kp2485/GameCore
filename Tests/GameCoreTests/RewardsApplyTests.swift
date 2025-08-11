//
//  RewardsApplyTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct RewardsApplyTests {

    @Test
    func foldAndApplyRewards() {
        // Fake a small event stream from a won battle
        let evs: [Event] = [
            Event(kind: .xpGained,    timestamp: 0, data: ["actor": "Hero", "amount": "250", "level": "1"]),
            Event(kind: .levelUp,     timestamp: 0, data: ["actor": "Hero", "newLevel": "2"]),
            Event(kind: .goldAwarded, timestamp: 0, data: ["amount": "75"]),
            Event(kind: .lootDropped, timestamp: 0, data: ["itemId": "herb", "qty": "2"]),
            Event(kind: .lootDropped, timestamp: 0, data: ["itemId": "gem",  "qty": "1"]),
            Event(kind: .lootDropped, timestamp: 0, data: ["itemId": "herb", "qty": "1"]), // same id collapses
        ]

        let summary = RewardSummary.from(events: evs)
        #expect(summary.totalXP == 250)
        #expect(summary.gold == 75)
        // herb should be 3 total after collapse
        #expect(summary.loot.contains(where: { $0.itemId == "herb" && $0.qty == 3 }))
        #expect(summary.loot.contains(where: { $0.itemId == "gem" && $0.qty == 1 }))
        #expect(summary.levelUps["Hero"] == 1)

        var inv = Inventory()
        var purse = GoldPurse()
        var applier = PartyRewardsApplier()
        applier.apply(summary, to: &inv, purse: &purse)

        #expect(purse.gold == 75)
        #expect(inv.quantity(of: "herb") == 3)
        #expect(inv.quantity(of: "gem") == 1)
    }
}
