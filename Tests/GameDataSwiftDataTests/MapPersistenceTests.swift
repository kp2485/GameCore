//
//  MapPersistenceTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//


#if canImport(SwiftData)
import Foundation
import Testing
@testable import GameMap
@testable import GameDataSwiftData

private func smallMap() -> GameMap {
    var m = GameMap(id: "floor1", name: "Floor 1", width: 3, height: 2, fill: Cell())
    // Add a locked door at (1,0), a wall north of (1,1)
    m[GridCoord(1,0)].feature = .door(locked: true, secret: false)
    m[GridCoord(1,1)].walls.insert(.north)
    return m
}

@Suite struct MapPersistenceTests {

    @Test @MainActor
    func upsertAndFetchMapRoundTrip() throws {
        let stack = try SDStack(inMemory: true)
        let repo = SDMapRepository(stack: stack)

        let map = smallMap()
        try repo.upsert(map)
        let fetched = try #require(try repo.fetchMap(id: "floor1"))

        #expect(fetched.id == map.id)
        #expect(fetched.width == 3 && fetched.height == 2)
        #expect(fetched[GridCoord(1,0)].feature == .door(locked: true, secret: false))
        #expect(fetched[GridCoord(1,1)].walls.contains(.north))
    }

    @Test @MainActor
    func fogBitsetSaveMergeLoad() throws {
        let stack = try SDStack(inMemory: true)
        let repo = SDMapRepository(stack: stack)
        let map = smallMap()
        try repo.upsert(map)

        let saveId = UUID()
        // Start with empty fog
        var fog = try repo.loadFog(saveId: saveId, mapId: map.id, tiles: map.width * map.height)
        #expect(fog.count == (map.width * map.height + 7) / 8)

        // Mark (0,0) and (2,1) as seen
        let idxA = 0 * map.width + 0
        let idxB = 1 * map.width + 2
        FogBits.set(&fog, index: idxA)
        FogBits.set(&fog, index: idxB)
        try repo.saveFog(saveId: saveId, mapId: map.id, bitset: fog)

        // Merge with another reveal that includes (1,0)
        var more = FogBits.makeEmpty(count: map.width * map.height)
        let idxC = 0 * map.width + 1
        FogBits.set(&more, index: idxC)
        let merged = try repo.mergeFog(saveId: saveId, mapId: map.id, additional: more)

        // Reload and verify all three bits set
        let re = try repo.loadFog(saveId: saveId, mapId: map.id, tiles: map.width * map.height)
        #expect(re == merged)
        #expect(FogBits.isSet(re, index: idxA))
        #expect(FogBits.isSet(re, index: idxB))
        #expect(FogBits.isSet(re, index: idxC))
    }
}
#endif