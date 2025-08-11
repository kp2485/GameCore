//
//  MapRepository.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData) && canImport(GameMap)
import Foundation
import SwiftData
import GameMap

@MainActor
public protocol MapRepository: Sendable {
    func upsert(_ map: GameMap) throws
    func fetchMap(id: String) throws -> GameMap?
    func deleteMap(id: String) throws

    func loadFog(saveId: UUID, mapId: String, tiles: Int) throws -> Data
    func saveFog(saveId: UUID, mapId: String, bitset: Data) throws
    func mergeFog(saveId: UUID, mapId: String, additional: Data) throws -> Data
}

@MainActor
public final class SDMapRepository: MapRepository {
    private let stack: SDStack
    public init(stack: SDStack) { self.stack = stack }

    public func upsert(_ map: GameMap) throws {
        let ctx = stack.context
        let mid = map.id
        var fd = FetchDescriptor<MapEntity>(predicate: #Predicate { $0.id == mid })
        fd.fetchLimit = 1

        // Encode cells + regions
        let cellsBlob = try MapCodec.encodeCells(map.cells)
        let regionsBlob = try RegionsCodec.encode(map.regions)

        if let row = try ctx.fetch(fd).first {
            row.name = map.name
            row.width = map.width
            row.height = map.height
            row.cellsBlob = cellsBlob
            row.codecVersion = MapCodec.currentVersion
            row.regionsBlob = regionsBlob
            row.regionsCodecVersion = RegionsCodec.currentVersion
        } else {
            ctx.insert(MapEntity(
                id: map.id,
                name: map.name,
                width: map.width,
                height: map.height,
                cellsBlob: cellsBlob,
                codecVersion: MapCodec.currentVersion,
                regionsBlob: regionsBlob,
                regionsCodecVersion: RegionsCodec.currentVersion
            ))
        }
        try ctx.save()
    }

    public func fetchMap(id: String) throws -> GameMap? {
        let ctx = stack.context
        let mid = id
        var fd = FetchDescriptor<MapEntity>(predicate: #Predicate { $0.id == mid })
        fd.fetchLimit = 1
        guard let row = try ctx.fetch(fd).first else { return nil }

        let cells = try MapCodec.decodeCells(row.cellsBlob)
        var regions: [String: MapRegion] = [:]
        if let blob = row.regionsBlob, !blob.isEmpty {
            regions = try RegionsCodec.decode(blob)
        }

        // Build a map and fill via subscript (respects encapsulation)
        var map = GameMap(id: row.id, name: row.name, width: row.width, height: row.height, fill: Cell(), regions: regions)
        for y in 0..<map.height {
            for x in 0..<map.width {
                let idx = y * map.width + x
                map[GridCoord(x, y)] = cells[idx]
            }
        }
        return map
    }

    public func deleteMap(id: String) throws {
        let ctx = stack.context
        let mid = id
        var fd = FetchDescriptor<MapEntity>(predicate: #Predicate { $0.id == mid })
        fd.fetchLimit = 1
        if let row = try ctx.fetch(fd).first {
            ctx.delete(row)
            try ctx.save()
        }
    }

    // MARK: Fog-of-war

    public func loadFog(saveId: UUID, mapId: String, tiles: Int) throws -> Data {
        let ctx = stack.context
        let sid = saveId, mid = mapId
        var fd = FetchDescriptor<SaveFogEntity>(predicate: #Predicate { $0.saveId == sid && $0.mapId == mid })
        fd.fetchLimit = 1
        if let row = try ctx.fetch(fd).first {
            return row.bitset
        } else {
            return FogBits.makeEmpty(count: tiles)
        }
    }

    public func saveFog(saveId: UUID, mapId: String, bitset: Data) throws {
        let ctx = stack.context
        let sid = saveId, mid = mapId
        var fd = FetchDescriptor<SaveFogEntity>(predicate: #Predicate { $0.saveId == sid && $0.mapId == mid })
        fd.fetchLimit = 1
        if let row = try ctx.fetch(fd).first {
            row.bitset = bitset
        } else {
            ctx.insert(SaveFogEntity(saveId: saveId, mapId: mapId, bitset: bitset))
        }
        try ctx.save()
    }

    public func mergeFog(saveId: UUID, mapId: String, additional: Data) throws -> Data {
        let ctx = stack.context
        let sid = saveId, mid = mapId
        var fd = FetchDescriptor<SaveFogEntity>(predicate: #Predicate { $0.saveId == sid && $0.mapId == mid })
        fd.fetchLimit = 1
        let current = try ctx.fetch(fd).first?.bitset ?? Data()
        let merged = FogBits.union(current, additional)
        if let row = try ctx.fetch(fd).first {
            row.bitset = merged
        } else {
            ctx.insert(SaveFogEntity(saveId: saveId, mapId: mapId, bitset: merged))
        }
        try ctx.save()
        return merged
    }
}
#endif
