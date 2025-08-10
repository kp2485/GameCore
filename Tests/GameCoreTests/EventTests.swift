//
//  EventTests.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation
import Testing
@testable import GameCore

@Suite struct EventTests {
    @Test func eventEqualityAndCoding() throws {
        let e1 = Event(kind: .note, timestamp: 42, data: ["k": "v"])
        let e2 = Event(kind: .note, timestamp: 42, data: ["k": "v"])
        #expect(e1 == e2)

        let data = try JSONEncoder().encode(e1)
        let decoded = try JSONDecoder().decode(Event.self, from: data)
        #expect(decoded == e1)
    }
}
