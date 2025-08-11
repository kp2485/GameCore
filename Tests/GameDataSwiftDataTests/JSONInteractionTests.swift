//
//  JSONInteractionTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData) && canImport(GameMap)
import Foundation
import Testing
@testable import GameCore
@testable import GameMap
@testable import GameDataSwiftData

private func jsonWithSecretDoorLeverAndNote() -> Data {
    """
    {
      "id":"floor-json",
      "name":"JSON Floor",
      "width":3,
      "height":1,
      "cells":[
        [
          { "terrain":0, "walls": [], "feature": { "kind":"none" } },
          { "terrain":0, "walls": [], "feature": { "kind":"lever", "id":"lv1", "isOn": false } },
          { "terrain":0, "walls": [], "feature": { "kind":"note", "text":"Secret nearby" } }
        ]
      ],
      "regions": {}
    }
    """.data(using: .utf8)!
}

@Suite struct JSONInteractionTests {
    @Test @MainActor
    func importThenInteractViaRuntime() throws {
        let stack = try SDStack(inMemory: true)
        let repo  = SDMapRepository(stack: stack)

        // Import map via JSON
        let importer = JSONMapImporter(repo: repo)
        let mapId = try importer.importMap(from: jsonWithSecretDoorLeverAndNote())
        #expect(mapId == "floor-json")

        // Fetch the map and explore
        let map = try #require(try repo.fetchMap(id: mapId))
        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)

        // Toggle lever at (1,0)
        #expect(rt.interactAhead() == .leverToggled(newState: true))

        // Step into (1,0)
        var rng: any Randomizer = SeededPRNG(seed: 42)
        _ = rt.moveForward(rng: &rng)

        // Read note at (2,0)
        #expect(rt.interactAhead() == .foundNote("Secret nearby"))
    }
}
#endif
