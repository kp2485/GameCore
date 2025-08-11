//
//  MapPersistenceSupport.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData) && canImport(GameMap)
import Foundation
import GameMap

// MARK: - Regions <-> JSON (for MapEntity.regionsBlob)

enum RegionsCodec {
    static let currentVersion = 1

    struct EncounterEntryDTO: Codable { var weight: Int; var battleId: String }
    struct EncounterTableDTO: Codable {
        var entries: [EncounterEntryDTO]
        var stepsPerCheck: Int
        var chancePercent: Int
    }
    struct RectDTO: Codable { var x: Int; var y: Int; var w: Int; var h: Int }
    struct RegionDTO: Codable {
        var rects: [RectDTO]
        var encounter: EncounterTableDTO?
    }

    static func encode(_ regions: [String: MapRegion]) throws -> Data {
        var dto: [String: RegionDTO] = [:]
        dto.reserveCapacity(regions.count)
        for (name, region) in regions {
            let rects = region.rects.map { RectDTO(x: $0.x, y: $0.y, w: $0.w, h: $0.h) }
            let enc: EncounterTableDTO? = region.encounter.map {
                EncounterTableDTO(
                    entries: $0.entries.map { EncounterEntryDTO(weight: $0.weight, battleId: $0.battleId) },
                    stepsPerCheck: $0.stepsPerCheck,
                    chancePercent: $0.chancePercent
                )
            }
            dto[name] = RegionDTO(rects: rects, encounter: enc)
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(dto)
    }

    static func decode(_ data: Data) throws -> [String: MapRegion] {
        let dec = JSONDecoder()
        let dto = try dec.decode([String: RegionDTO].self, from: data)
        var out: [String: MapRegion] = [:]
        out.reserveCapacity(dto.count)
        for (name, r) in dto {
            let rects = r.rects.map { Rect(x: $0.x, y: $0.y, w: $0.w, h: $0.h) }
            let enc: EncounterTable? = r.encounter.map {
                EncounterTable(
                    entries: $0.entries.map { .init(weight: $0.weight, battleId: $0.battleId) },
                    stepsPerCheck: $0.stepsPerCheck,
                    chancePercent: $0.chancePercent
                )
            }
            out[name] = MapRegion(rects: rects, encounter: enc)
        }
        return out
    }
}

// MARK: - Fog bitset helpers (1 bit per tile)

enum FogBits {
    static func makeEmpty(count: Int) -> Data {
        Data(repeating: 0, count: (count + 7) / 8)
    }
    static func isSet(_ data: Data, index: Int) -> Bool {
        let byte = index >> 3, bit = index & 7
        guard byte < data.count else { return false }
        return (data[byte] & (1 << bit)) != 0
    }
    static func set(_ data: inout Data, index: Int) {
        let byte = index >> 3, bit = index & 7
        guard byte < data.count else { return }
        data[byte] |= (1 << bit)
    }
    static func union(_ a: Data, _ b: Data) -> Data {
        let n = max(a.count, b.count)
        var out = Data(repeating: 0, count: n)
        for i in 0..<n {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            out[i] = av | bv
        }
        return out
    }
}
#endif
