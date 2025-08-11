//
//  RewardsToSaveTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Testing
@testable import GameCore
@testable import GameDataSwiftData

@Suite @MainActor
struct RewardsToSaveTests {

    @Test
    func applyRewardsPersistsGoldAndItems() throws {
        let stack = try SDStack(inMemory: true)
        let repo  = SDGameSaveRepository(stack: stack)

        // Seed a save with one member
        let hero = Character(name: "Hero", stats: StatBlock([.hp: 30]))
        let provider = ClosureGameStateProvider(members: { [hero] })
        let svc  = GameSaveService(repo: repo, provider: provider)
        let saveId = try svc.saveCurrentGame(name: "S1")

        // Fake reward events from combat
        let evs: [Event] = [
            Event(kind: .goldAwarded, timestamp: 0, data: ["amount": "125"]),
            Event(kind: .lootDropped, timestamp: 0, data: ["itemId": "herb", "qty": "2"]),
            Event(kind: .lootDropped, timestamp: 0, data: ["itemId": "gem",  "qty": "1"]),
        ]

        _ = try svc.applyBattleRewards(saveId: saveId, events: evs, distribution: .toFirstPartyMember)

        // Verify
        #expect(try repo.currentGold(saveId: saveId) == 125)

        let loaded = try svc.loadGame(id: saveId)
        let bag = loaded.inventoriesById[hero.id] ?? [:]
        #expect(bag["herb"] == 2)
        #expect(bag["gem"] == 1)
    }
}
#endif
