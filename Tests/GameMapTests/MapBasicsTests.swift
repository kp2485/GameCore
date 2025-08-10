//
//  MapBasicsTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameMap

@Suite struct MapBasicsTests {
    @Test func indexAndBounds() {
        var map = GameMap(id: "m", name: "Map", width: 4, height: 3)
        #expect(map.inBounds(GridCoord(0,0)))
        #expect(!map.inBounds(GridCoord(-1,0)))
        map[GridCoord(1,1)] = Cell(terrain: 2)
        #expect(map[GridCoord(1,1)].terrain == 2)
        #expect(map.index(GridCoord(3,2)) == 11)
    }

    @Test func navigationBlocksWallsAndDoors() {
        var map = GameMap(id: "m", name: "Map", width: 3, height: 1, fill: Cell())

        // Put a solid wall between (0,0) and (1,0). Moving east from (0,0) should be blocked.
        map[GridCoord(0,0)].walls.insert(.east)
        #expect(!Navigation.canMove(from: GridCoord(0,0), toward: .east, on: map))

        // Locked door on (1,0) also blocks movement either way.
        map[GridCoord(1,0)].feature = .door(locked: true, secret: false)
        #expect(!Navigation.canMove(from: GridCoord(0,0), toward: .east, on: map))
        #expect(!Navigation.canMove(from: GridCoord(1,0), toward: .east, on: map))

        // Now unlock/remove the blocker to prove open movement works.
        map[GridCoord(0,0)].walls.remove(.east)
        map[GridCoord(1,0)].feature = .none
        #expect(Navigation.canMove(from: GridCoord(1,0), toward: .east, on: map))
    }
}
