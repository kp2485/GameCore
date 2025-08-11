//
//  JSONMapIOTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData) && canImport(GameMap)
import Foundation
import Testing
@testable import GameMap
@testable import GameDataSwiftData

private func sampleMapJSON() -> Data {
    """
    {
      "id":"floor1",
      "name":"Floor 1",
      "width":3,
      "height":1,
      "cells":[
        [
          {"terrain":0,"walls":["E"],"feature":{"kind":"none"}},
          {"terrain":0,"walls":[],"feature":{"kind":"door","locked":true,"secret":false}},
          {"terrain":0,"walls":[],"feature":{"kind":"none"}}
        ]
      ],
      "regions":{
        "right":{
          "rects":[{"x":2,"y":0,"w":1,"h":1}],
          "encounter":{"entries":[{"weight":1,"battleId":"slime"}],"stepsPerCheck":1,"chancePercent":100}
        }
      }
    }
    """.data(using: .utf8)!
}

@Suite struct JSONMapIOTests {

    @Test @MainActor
    func importUpsertFetchExportRoundTrip() throws {
        let stack = try SDStack(inMemory: true)
        let repo = SDMapRepository(stack: stack)

        let importer = JSONMapImporter(repo: repo)
        let id = try importer.importMap(from: sampleMapJSON())
        #expect(id == "floor1")

        // Fetch and verify a few properties
        let map = try #require(try repo.fetchMap(id: "floor1"))
        #expect(map.width == 3 && map.height == 1)
        #expect(map[GridCoord(0,0)].walls.contains(.east))
        #expect(map[GridCoord(1,0)].feature == .door(locked: true, secret: false))
        #expect(map.regions["right"] != nil)

        // Export back to JSON and ensure it decodes as the same DTO shape
        let exporter = JSONMapExporter(repo: repo)
        let data = try exporter.exportMap(id: "floor1")
        let decoded = try JSONDecoder().decode(MapBundleDTO.self, from: data)
        #expect(decoded.id == "floor1")
        #expect(decoded.cells.count == 1 && decoded.cells[0].count == 3)
        #expect(decoded.regions.keys.contains("right"))
    }

    @Test
    func dtoWallsCodecIsStable() {
        // Quick sanity: encode/decode walls vector
        let w: CellWalls = [.north, .south, .secret]
        let names = MapDTOCodec.wallsToDTO(w)
        #expect(Set(names) == Set(["N","S","SECRET"]))
        let back = MapDTOCodec.wallsFromDTO(names)
        #expect(back.contains(.north) && back.contains(.south) && back.contains(.secret) && !back.contains(.east))
    }
}
#endif
