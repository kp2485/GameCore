//
//  JSONIOTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import Testing
@testable import GameCore
@testable import GameDataSwiftData

private func sampleRacesJSON() -> Data {
    """
    [
      {"id":"human","name":"Human","statBonuses":{"str":1,"int":1},"tags":[]},
      {"id":"dwarf","name":"Dwarf","statBonuses":{"vit":2},"tags":["stout"]}
    ]
    """.data(using: .utf8)!
}

private func sampleClassesJSON() -> Data {
    """
    [
      {"id":"fighter","name":"Fighter","minStats":{"str":6,"vit":6},"allowedWeapons":["blade","blunt"],"allowedArmor":["light","heavy"],"startingTags":["martial"],"startingLevel":1},
      {"id":"mage","name":"Mage","minStats":{"int":7},"allowedWeapons":["staff"],"allowedArmor":["robe"],"startingTags":["arcane"],"startingLevel":1}
    ]
    """.data(using: .utf8)!
}

private func sampleItemsJSON() -> Data {
    """
    [
      {"id":"sw1","name":"Shortsword","kind":"weapon","tags":["blade"],"baseDamage":4,"scaling":"strDivisor","scalingParam":2},
      {"id":"helm","name":"Bronze Helm","kind":"armor","tags":["light"],"mitigationPercent":15}
    ]
    """.data(using: .utf8)!
}

@Suite struct JSONIOTests {

    @Test @MainActor
    func importSeedAndExport() throws {
        let stack = try SDStack(inMemory: true)
        let raceRepo = SDRaceRepository(stack: stack)
        let classRepo = SDClassRepository(stack: stack)
        let itemRepo = SDItemRepository(stack: stack)

        let importer = JSONImporter(races: raceRepo, classes: classRepo, items: itemRepo)

        // Import all three categories
        #expect(try importer.importRaces(data: sampleRacesJSON()) == 2)
        #expect(try importer.importClasses(data: sampleClassesJSON()) == 2)
        #expect(try importer.importItems(data: sampleItemsJSON()) == 2)

        // Export and sanity check round-trip structure
        let exporter = JSONExporter(races: raceRepo, classes: classRepo, items: itemRepo)
        let racesJSON = try exporter.exportRaces()
        let classesJSON = try exporter.exportClasses()
        let itemsJSON = try exporter.exportItems()

        // Decode back to DTOs to verify shape
        let races = try JSONDecoder().decode([RaceDTO].self, from: racesJSON)
        let classes = try JSONDecoder().decode([ClassDTO].self, from: classesJSON)
        let items = try JSONDecoder().decode([ItemDTO].self, from: itemsJSON)

        #expect(races.count == 2)
        #expect(classes.count == 2)
        #expect(items.count == 2)

        #expect(races.first?.id == "dwarf" || races.first?.id == "human")
        #expect(items.contains { $0.id == "sw1" && $0.kind == .weapon })
        #expect(items.contains { $0.id == "helm" && $0.kind == .armor })
    }

    @Test @MainActor
    func badStatKeyFailsGracefully() {
        let stack = try! SDStack(inMemory: true)
        let importer = JSONImporter(races: SDRaceRepository(stack: stack),
                                    classes: SDClassRepository(stack: stack),
                                    items: SDItemRepository(stack: stack))
        let bad = """
        [{"id":"x","name":"X","statBonuses":{"weird":1}}]
        """.data(using: .utf8)!
        do {
            _ = try importer.importRaces(data: bad)
            Issue.record("Expected failure for bad stat key")
        } catch {
            #expect(true) // ok
        }
    }
}
#endif
