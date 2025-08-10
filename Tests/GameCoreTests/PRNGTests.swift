//
//  PRNGTests.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct PRNGTests {
    @Test func determinism() {
        var a = SeededPRNG(seed: 12345)
        var b = SeededPRNG(seed: 12345)
        #expect(a.next() == b.next())
        #expect(a.next() == b.next())
        #expect(a.uniform(1000) == b.uniform(1000))
    }

    @Test func uniformWithinBounds() {
        var rng = SeededPRNG(seed: 1)
        for _ in 0..<10_000 {
            let r = rng.uniform(17)
            #expect(r < 17)
        }
    }
}
