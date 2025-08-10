//
//  CharacterPartyTests.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct CharacterPartyTests {
    @Test func characterBasics() {
        let stats = StatBlock<CoreStat>([.str: 6, .vit: 5, .agi: 4, .int: 1, .spi: 2, .luc: 3])
        let hero = Character(name: "Arden", stats: stats)
        #expect(hero.name == "Arden")
        #expect(hero.stats[.str] == 6)
        #expect(hero.tags.isEmpty)
    }

    @Test func partyOrderAndEquality() {
        let a = Character(name: "A", stats: .init([.str: 1]))
        let b = Character(name: "B", stats: .init([.str: 1]))
        let party = Party([a, b])
        #expect(party.count == 2)
        #expect(party[0].name == "A")
        #expect(a != b)
    }
}
