//
//  JSONIO.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import GameCore

// MARK: - DTOs

public enum DTOError: Error, CustomStringConvertible {
    case invalid(String)
    public var description: String { switch self { case .invalid(let m): return m } }
}

public struct RaceDTO: Codable, Sendable {
    public var id: String
    public var name: String
    public var statBonuses: [String: Int] = [:] // "str": 1 ...
    public var tags: [String] = []
}

public struct ClassDTO: Codable, Sendable {
    public var id: String
    public var name: String
    public var minStats: [String: Int] = [:]
    public var allowedWeapons: [String] = []
    public var allowedArmor: [String] = []
    public var startingTags: [String] = []
    public var startingLevel: Int = 1
}

public enum ItemKindDTO: String, Codable, Sendable { case weapon, armor }
public enum ScalingKindDTO: String, Codable, Sendable { case none, strDivisor }

public struct ItemDTO: Codable, Sendable {
    public var id: String
    public var name: String
    public var kind: ItemKindDTO
    public var tags: [String] = []

    // weapon
    public var baseDamage: Int?
    public var scaling: ScalingKindDTO?
    public var scalingParam: Int?

    // armor
    public var mitigationPercent: Int?
}

// MARK: - Codec helpers

@inline(__always)
private func statKey(_ s: String) throws -> CoreStat {
    switch s.lowercased() {
    case "hp": return .hp
    case "mp": return .mp
    case "str": return .str
    case "vit": return .vit
    case "agi": return .agi
    case "int": return .int
    case "spi": return .spi
    case "luc": return .luc
    default: throw DTOError.invalid("Unknown stat key '\(s)'")
    }
}

private func decodeStats(_ dict: [String:Int]) throws -> [CoreStat:Int] {
    var out: [CoreStat:Int] = [:]
    for (k,v) in dict { out[try statKey(k)] = v }
    return out
}

private func encodeStats(_ dict: [CoreStat:Int]) -> [String:Int] {
    var out: [String:Int] = [:]
    for (k,v) in dict { out[k.rawValue] = v }
    return out
}

// MARK: - Importer

@MainActor
public struct JSONImporter: Sendable {
    let races: SDRaceRepository
    let classes: SDClassRepository
    let items: SDItemRepository

    public init(races: SDRaceRepository, classes: SDClassRepository, items: SDItemRepository) {
        self.races = races
        self.classes = classes
        self.items = items
    }

    public func importRaces(data: Data) throws -> Int {
        let arr = try JSONDecoder().decode([RaceDTO].self, from: data)
        for r in arr {
            try races.upsert(Race(id: r.id,
                                  name: r.name,
                                  statBonuses: try decodeStats(r.statBonuses),
                                  tags: Set(r.tags)))
        }
        return arr.count
    }

    public func importClasses(data: Data) throws -> Int {
        let arr = try JSONDecoder().decode([ClassDTO].self, from: data)
        for c in arr {
            try classes.upsert(ClassDef(id: c.id,
                                        name: c.name,
                                        minStats: try decodeStats(c.minStats),
                                        allowedWeapons: Set(c.allowedWeapons),
                                        allowedArmor: Set(c.allowedArmor),
                                        startingTags: Set(c.startingTags),
                                        startingLevel: c.startingLevel))
        }
        return arr.count
    }

    public func importItems(data: Data) throws -> Int {
        let arr = try JSONDecoder().decode([ItemDTO].self, from: data)
        for i in arr {
            switch i.kind {
            case .weapon:
                guard let base = i.baseDamage else { throw DTOError.invalid("Weapon \(i.id) missing baseDamage") }
                let sk = (i.scaling ?? .none)
                let param = (i.scalingParam ?? 1)
                try items.upsertWeapon(id: i.id, name: i.name, tags: i.tags, baseDamage: base,
                                       scaling: sk == .none ? .none : .strDivisor, param: param)
            case .armor:
                guard let pct = i.mitigationPercent else { throw DTOError.invalid("Armor \(i.id) missing mitigationPercent") }
                try items.upsertArmor(id: i.id, name: i.name, tags: i.tags, mitigationPercent: pct)
            }
        }
        return arr.count
    }
}

// MARK: - Exporter

@MainActor
public struct JSONExporter: Sendable {
    let races: SDRaceRepository
    let classes: SDClassRepository
    let items: SDItemRepository

    public init(races: SDRaceRepository, classes: SDClassRepository, items: SDItemRepository) {
        self.races = races
        self.classes = classes
        self.items = items
    }

    public func exportRaces(pretty: Bool = true) throws -> Data {
        let all = try races.allRaces()
        let dtos = all.map { RaceDTO(id: $0.id, name: $0.name, statBonuses: encodeStats($0.statBonuses), tags: Array($0.tags)) }
        return try encodeJSON(dtos, pretty: pretty)
    }

    public func exportClasses(pretty: Bool = true) throws -> Data {
        let all = try classes.allClasses()
        let dtos = all.map {
            ClassDTO(id: $0.id, name: $0.name, minStats: encodeStats($0.minStats),
                     allowedWeapons: Array($0.allowedWeapons),
                     allowedArmor: Array($0.allowedArmor),
                     startingTags: Array($0.startingTags),
                     startingLevel: $0.startingLevel)
        }
        return try encodeJSON(dtos, pretty: pretty)
    }

    public func exportItems(pretty: Bool = true) throws -> Data {
        let all = try items.fetchAll()
        let dtos: [ItemDTO] = all.map { item in
            if let w = item as? Weapon {
                // We can’t reflect the exact closure; we only persisted two scaling modes.
                // Assume .none if scale would be 0 for a neutral stat block.
                ItemDTO(id: w.id, name: w.name, kind: .weapon, tags: Array(w.tags),
                        baseDamage: w.baseDamage, scaling: ScalingKindDTO.none, scalingParam: 1, mitigationPercent: nil)
            } else if let a = item as? Armor {
                ItemDTO(id: a.id, name: a.name, kind: .armor, tags: Array(a.tags),
                        baseDamage: nil, scaling: nil, scalingParam: nil, mitigationPercent: a.mitigationPercent)
            } else {
                ItemDTO(id: item.id, name: item.name, kind: .weapon, tags: Array(item.tags))
            }
        }
        return try encodeJSON(dtos, pretty: pretty)
    }

    private func encodeJSON<T: Encodable>(_ value: T, pretty: Bool) throws -> Data {
        let enc = JSONEncoder()
        if pretty { enc.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try enc.encode(value)
    }
}

public struct ContentBundleDTO: Codable, Sendable {
    public var races: [RaceDTO] = []
    public var classes: [ClassDTO] = []
    public var items: [ItemDTO] = []
}

@MainActor
public extension JSONImporter {
    /// Import a single JSON bundle: { "races": [...], "classes": [...], "items": [...] }
    func importBundle(data: Data) throws -> (races: Int, classes: Int, items: Int) {
        let bundle = try JSONDecoder().decode(ContentBundleDTO.self, from: data)
        let rc = try importRaces(data: try JSONEncoder().encode(bundle.races))
        let cc = try importClasses(data: try JSONEncoder().encode(bundle.classes))
        let ic = try importItems(data: try JSONEncoder().encode(bundle.items))
        return (rc, cc, ic)
    }
}

@MainActor
public extension JSONExporter {
    /// Export one bundle that includes all races/classes/items in the store.
    func exportBundle(pretty: Bool = true) throws -> Data {
        let racesJSON = try JSONDecoder().decode([RaceDTO].self, from: exportRaces(pretty: false))
        let classesJSON = try JSONDecoder().decode([ClassDTO].self, from: exportClasses(pretty: false))
        let itemsJSON = try JSONDecoder().decode([ItemDTO].self, from: exportItems(pretty: false))
        let bundle = ContentBundleDTO(races: racesJSON, classes: classesJSON, items: itemsJSON)
        let enc = JSONEncoder()
        if pretty { enc.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try enc.encode(bundle)
    }
}
#endif
