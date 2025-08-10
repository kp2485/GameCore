//
//  PathfindingTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameMap

@Suite struct PathfindingTests {
    @Test func aStarFindsShortestPathAroundSingleBlock() {
        var map = GameMap(id: "m", name: "M", width: 5, height: 5, fill: Cell())

        // Block a single tile at the center (2,2). Our "passable" rule treats tiles with any walls as blocked.
        map[GridCoord(2,2)].walls.insert(.north)

        let start = GridCoord(0,2)
        let goal  = GridCoord(4,2)

        // Passable if the tile itself has no walls (simple rule for this test).
        let path = Pathfinder.aStar(from: start, to: goal, on: map) { p in
            map[p].walls.isEmpty
        }

        #expect(!path.isEmpty)
        #expect(path.first == start)
        #expect(path.last == goal)

        // Ensure the path actually routes around the blocked center tile.
        #expect(!path.contains(GridCoord(2,2)))
    }
}
