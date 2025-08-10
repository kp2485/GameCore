//
//  LOSFOVTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//


import Testing
@testable import GameMap

@Suite struct LOSFOVTests {
    @Test func bresenhamLineSimple() {
        let pts = LOS.line(from: GridCoord(0,0), to: GridCoord(3,2))
        #expect(pts.first == GridCoord(0,0))
        #expect(pts.last == GridCoord(3,2))
        #expect(!pts.isEmpty)
    }

    @Test func fovBlockedByWall() {
        var map = GameMap(id: "m", name: "M", width: 5, height: 3, fill: Cell())
        // Create a horizontal wall strip at y=1 across x=0..4
        for x in 0..<5 {
            map[GridCoord(x,1)].walls.insert(.north) // top edge of row 1 is a wall seen from row 0
        }
        let origin = GridCoord(2,0)
        let vis = LOS.visible(from: origin, radius: 5, on: map)
        #expect(vis.contains(origin))
        // Tiles below the wall should generally be blocked
        #expect(!vis.contains(GridCoord(2,2)))
    }
}