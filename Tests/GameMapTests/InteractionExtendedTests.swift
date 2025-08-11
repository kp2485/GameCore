//
//  InteractionExtendedTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameMap
@testable import GameCore

@Suite struct InteractionExtendedTests {
    @Test
    func leverToggleAndNoteRead() {
        var map = GameMap(id: "m", name: "M", width: 3, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .lever(id: "lv1", isOn: false)
        map[GridCoord(2,0)].feature = .note(text: "Beware!")

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)

        // Toggle lever at (1,0)
        #expect(rt.interactAhead() == .leverToggled(newState: true))
        // Move into (1,0), then read note at (2,0)
        var rng: any Randomizer = SeededPRNG(seed: 1)
        _ = rt.moveForward(rng: &rng)
        #expect(rt.interactAhead() == .foundNote("Beware!"))
    }
}
