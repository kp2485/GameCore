//
//  StatBlockTests.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct StatBlockTests {
    @Test func initAndSubscript() {
        var sb = StatBlock<CoreStat>([.str: 5, .vit: 4])
        #expect(sb[.str] == 5)
        #expect(sb[.vit] == 4)
        sb[.agi] = 7
        #expect(sb[.agi] == 7)
    }

    @Test func addAndUnion() {
        var a = StatBlock<CoreStat>([.str: 2])
        a.add(.str, 3)
        #expect(a[.str] == 5)

        let b = StatBlock<CoreStat>([.str: 1, .vit: 2])
        let c = a.union(b)
        #expect(c[.str] == 6)
        #expect(c[.vit] == 2)
    }

    @Test func derivedConvenience() {
        var sb = StatBlock<CoreStat>([.vit: 5, .spi: 2, .int: 1])
        #expect(sb.maxHP == 50)
        #expect(sb.maxMP == 13)
        sb[.vit] = 0
        #expect(sb.maxHP == 1)
    }
}
