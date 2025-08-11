//
//  JSONMapIO.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData) && canImport(GameMap)
import Foundation
import GameMap

// MARK: - Public JSON schema

/// Top-level JSON structure for a map.
/// Example:
/// {
///   "id": "floor1", "name": "Floor 1", "width": 3, "height": 1,
///   "cells": [ [ {"terrain":0,"walls":["E"],"feature":{"kind":"none"}}, {"terrain":0,"walls":[],"feature":{"kind":"none"}}, {"terrain":0,"walls":[],"feature":{"kind":"none"}} ] ],
///   "regions": {
///     "right": { "rects":[{"x":2,"y":0,"w":1,"h":1}],
///                "encounter": { "stepsPerCheck":1, "chancePercent":100,
///                               "entries":[{"weight":1,"battleId":"slime"}] } }
///   }
/// }
public struct MapBundleDTO: Codable, Sendable {
    public var id: String
    public var name: String
    public var width: Int
    public var height: Int
    public var cells: [[CellDTO]]
    public var regions: [String: RegionDTO] = [:]
}

public struct CellDTO: Codable, Sendable {
    public var terrain: UInt8
    public var walls: [String] = []                 // "N","E","S","W","SECRET"
    public var feature: FeatureDTO = .init(kind: .none)
    
    public init(terrain: UInt8, walls: [String] = [], feature: FeatureDTO = .init(kind: .none)) {
        self.terrain = terrain; self.walls = walls; self.feature = feature
    }
}

public struct FeatureDTO: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case none, door, stairsUp, stairsDown, portal, chest, trigger, note, lever, trap // ← add trap
    }
    public var kind: Kind

    // door
    public var locked: Bool?
    public var secret: Bool?
    public var lockDC: Int?
    public var lockSkill: String?

    // portal
    public var mapId: String?
    public var toX: Int?
    public var toY: Int?

    // chest / trigger / lever
    public var id: String?
    public var isOn: Bool?

    // note
    public var text: String?

    // trap
    public var detectDC: Int?
    public var disarmDC: Int?
    public var damage: Int?
    public var once: Bool?
    public var armed: Bool?

    public init(kind: Kind) { self.kind = kind }
}

public struct RegionDTO: Codable, Sendable {
    public var rects: [RectDTO]
    public var encounter: EncounterTableDTO?
    public init(rects: [RectDTO], encounter: EncounterTableDTO? = nil) { self.rects = rects; self.encounter = encounter }
}

public struct RectDTO: Codable, Sendable {
    public var x: Int; public var y: Int; public var w: Int; public var h: Int
    public init(x: Int, y: Int, w: Int, h: Int) { self.x = x; self.y = y; self.w = w; self.h = h }
}

public struct EncounterTableDTO: Codable, Sendable {
    public struct EntryDTO: Codable, Sendable { public var weight: Int; public var battleId: String }
    public var entries: [EntryDTO]
    public var stepsPerCheck: Int
    public var chancePercent: Int
}

// MARK: - Runtime ↔︎ DTO conversion

enum MapDTOCodec {
    // Walls: "N","E","S","W","SECRET"
    static func wallsToDTO(_ walls: CellWalls) -> [String] {
        var out: [String] = []
        if walls.contains(.north) { out.append("N") }
        if walls.contains(.east)  { out.append("E") }
        if walls.contains(.south) { out.append("S") }
        if walls.contains(.west)  { out.append("W") }
        if walls.contains(.secret){ out.append("SECRET") }
        return out
    }
    static func wallsFromDTO(_ arr: [String]) -> CellWalls {
        var w: CellWalls = []
        for s in arr {
            switch s.uppercased() {
            case "N": w.insert(.north)
            case "E": w.insert(.east)
            case "S": w.insert(.south)
            case "W": w.insert(.west)
            case "SECRET": w.insert(.secret)
            default: break
            }
        }
        return w
    }
    
    static func featureToDTO(_ f: Feature) -> FeatureDTO {
        switch f {
        case .none:
            return FeatureDTO(kind: .none)
        case let .door(locked, secret, lockDC, lockSkill):
            var d = FeatureDTO(kind: .door)
            d.locked = locked
            d.secret = secret
            d.lockDC = lockDC
            d.lockSkill = lockSkill
            return d
        case .stairsUp:
            return FeatureDTO(kind: .stairsUp)
        case .stairsDown:
            return FeatureDTO(kind: .stairsDown)
        case let .portal(mapId, to):
            var d = FeatureDTO(kind: .portal); d.mapId = mapId; d.toX = to.x; d.toY = to.y; return d
        case let .chest(id, locked):
            var d = FeatureDTO(kind: .chest); d.id = id; d.locked = locked; return d
        case let .trigger(id):
            var d = FeatureDTO(kind: .trigger); d.id = id; return d
        case let .note(text):
            var d = FeatureDTO(kind: .note); d.text = text; return d
        case let .lever(id, isOn):
            var d = FeatureDTO(kind: .lever); d.id = id; d.isOn = isOn; return d
        case .trap(id: let tid, detectDC: let det, disarmDC: let dis, damage: let dmg, once: let once, armed: let armed):
            var d = FeatureDTO(kind: .trap)
            d.id = tid; d.detectDC = det; d.disarmDC = dis; d.damage = dmg; d.once = once; d.armed = armed
            return d
        }
    }
    
    static func featureFromDTO(_ d: FeatureDTO) -> Feature {
        switch d.kind {
        case .none: return .none
        case .door:
            return .door(
                locked: d.locked ?? false,
                secret: d.secret ?? false,
                lockDC: d.lockDC,
                lockSkill: d.lockSkill
            )
        case .stairsUp: return .stairsUp
        case .stairsDown: return .stairsDown
        case .portal: return .portal(mapId: d.mapId ?? "", to: GridCoord(d.toX ?? 0, d.toY ?? 0))
        case .chest: return .chest(id: d.id ?? "", locked: d.locked ?? false)
        case .trigger: return .trigger(id: d.id ?? "")
        case .note: return .note(text: d.text ?? "")
        case .lever: return .lever(id: d.id ?? "", isOn: d.isOn ?? false)
        case .trap: return .trap(id: d.id ?? "",
                                 detectDC: d.detectDC ?? 60,
                                 disarmDC: d.disarmDC ?? 60,
                                 damage: d.damage ?? 10,
                                 once: d.once ?? true,
                                 armed: d.armed ?? true)
        }
    }
    
    static func regionToDTO(_ r: MapRegion) -> RegionDTO {
        let rects = r.rects.map { RectDTO(x: $0.x, y: $0.y, w: $0.w, h: $0.h) }
        let enc: EncounterTableDTO? = r.encounter.map { t in
            EncounterTableDTO(
                entries: t.entries.map { .init(weight: $0.weight, battleId: $0.battleId) },
                stepsPerCheck: t.stepsPerCheck,
                chancePercent: t.chancePercent
            )
        }
        return RegionDTO(rects: rects, encounter: enc)
    }
    
    static func regionFromDTO(_ d: RegionDTO) -> MapRegion {
        let rects = d.rects.map { Rect(x: $0.x, y: $0.y, w: $0.w, h: $0.h) }
        let enc: EncounterTable? = d.encounter.map { t in
            EncounterTable(
                entries: t.entries.map { .init(weight: $0.weight, battleId: $0.battleId) },
                stepsPerCheck: t.stepsPerCheck,
                chancePercent: t.chancePercent
            )
        }
        return MapRegion(rects: rects, encounter: enc)
    }
    
    static func toDTO(_ map: GameMap) -> MapBundleDTO {
        var rows: [[CellDTO]] = Array(repeating: Array(repeating: CellDTO(terrain: 0), count: map.width),
                                      count: map.height)
        for y in 0..<map.height {
            for x in 0..<map.width {
                let c = map[GridCoord(x, y)]
                rows[y][x] = CellDTO(terrain: c.terrain, walls: wallsToDTO(c.walls), feature: featureToDTO(c.feature))
            }
        }
        let regionsDTO = map.regions.mapValues { regionToDTO($0) }
        return MapBundleDTO(id: map.id, name: map.name, width: map.width, height: map.height, cells: rows, regions: regionsDTO)
    }
    
    static func fromDTO(_ dto: MapBundleDTO) throws -> GameMap {
        precondition(dto.height > 0 && dto.width > 0, "Map must have positive dimensions")
        guard dto.cells.count == dto.height else { throw CocoaError(.fileReadCorruptFile) }
        for row in dto.cells { if row.count != dto.width { throw CocoaError(.fileReadCorruptFile) } }
        
        var map = GameMap(id: dto.id, name: dto.name, width: dto.width, height: dto.height, fill: Cell(), regions: [:])
        for y in 0..<dto.height {
            for x in 0..<dto.width {
                let d = dto.cells[y][x]
                map[GridCoord(x, y)] = Cell(terrain: d.terrain, walls: wallsFromDTO(d.walls), feature: featureFromDTO(d.feature))
            }
        }
        if !dto.regions.isEmpty {
            map.regions = dto.regions.mapValues { regionFromDTO($0) }
        }
        return map
    }
}

// MARK: - Importer / Exporter

@MainActor
public struct JSONMapImporter: Sendable {
    private let repo: SDMapRepository
    public init(repo: SDMapRepository) { self.repo = repo }
    
    /// Parse a JSON map and upsert into SwiftData. Returns the map id.
    public func importMap(from data: Data) throws -> String {
        let dec = JSONDecoder()
        let bundle = try dec.decode(MapBundleDTO.self, from: data)
        let map = try MapDTOCodec.fromDTO(bundle)
        try repo.upsert(map)
        return map.id
    }
}

@MainActor
public struct JSONMapExporter: Sendable {
    private let repo: SDMapRepository
    public init(repo: SDMapRepository) { self.repo = repo }
    
    /// Fetch a map and serialize to JSON (pretty by default).
    public func exportMap(id: String, pretty: Bool = true) throws -> Data {
        guard let map = try repo.fetchMap(id: id) else { throw CocoaError(.fileNoSuchFile) }
        let dto = MapDTOCodec.toDTO(map)
        let enc = JSONEncoder()
        if pretty { enc.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try enc.encode(dto)
    }
}
#endif
