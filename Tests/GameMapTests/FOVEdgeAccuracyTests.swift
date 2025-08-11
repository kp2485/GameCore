//
//  FOVEdgeAccuracyTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameMap

@Suite struct FOVEdgeAccuracyTests {
    @Test
    func wallOnEdgeBlocksRayButNotWholeTile() {
        // 3x1: [A][W][B] — a wall on the edge between A and W should block visibility to B from A.
        var map = GameMap(id: "m", name: "M", width: 3, height: 1, fill: Cell())
        // Put a wall on the east edge of (0,0)
        map[GridCoord(0,0)].walls.insert(.east)

        let origin = GridCoord(0,0)
        let vis = LOS.visible(from: origin, radius: 3, on: map)

        // A sees itself and W, but not B past the walled edge.
        #expect(vis.contains(GridCoord(0,0)))
        #expect(vis.contains(GridCoord(1,0)))
        #expect(!vis.contains(GridCoord(2,0)))
    }
}
