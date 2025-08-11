//
//  MapCodec.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData) && canImport(GameMap)
import Foundation
import GameMap

/// v4: add trap feature
enum MapCodec {
    static let currentVersion = 4

    struct CellDTO: Codable {
        var terrain: UInt8
        var walls: UInt8
        enum FeatureDTO: Codable {
            case none
            case door(locked: Bool, secret: Bool, lockDC: Int?, lockSkill: String?)
            case stairsUp
            case stairsDown
            case portal(mapId: String, toX: Int, toY: Int)
            case chest(id: String, locked: Bool)
            case trigger(id: String)
            case note(text: String)
            case lever(id: String, isOn: Bool)
            case trap(id: String, detectDC: Int, disarmDC: Int, damage: Int, once: Bool, armed: Bool)
        }
        var feature: FeatureDTO

        init(from cell: Cell) {
            terrain = cell.terrain
            walls = cell.walls.rawValue
            switch cell.feature {
            case .none:
                feature = .none
            case .door(locked: let locked, secret: let secret, lockDC: let dc, lockSkill: let skill):
                feature = .door(locked: locked, secret: secret, lockDC: dc, lockSkill: skill)
            case .stairsUp:
                feature = .stairsUp
            case .stairsDown:
                feature = .stairsDown
            case .portal(mapId: let mapId, to: let to):
                feature = .portal(mapId: mapId, toX: to.x, toY: to.y)
            case .chest(id: let id, locked: let locked):
                feature = .chest(id: id, locked: locked)
            case .trigger(id: let id):
                feature = .trigger(id: id)
            case .note(text: let text):
                feature = .note(text: text)
            case .lever(id: let id, isOn: let isOn):
                feature = .lever(id: id, isOn: isOn)
            case .trap(id: let tid, detectDC: let det, disarmDC: let dis, damage: let dmg, once: let once, armed: let armed):
                feature = .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: armed)
            }
        }

        func toRuntime() -> Cell {
            let f: Feature
            switch feature {
            case .none:
                f = .none
            case .door(locked: let locked, secret: let secret, lockDC: let dc, lockSkill: let skill):
                f = .door(locked: locked, secret: secret, lockDC: dc, lockSkill: skill)
            case .stairsUp:
                f = .stairsUp
            case .stairsDown:
                f = .stairsDown
            case .portal(mapId: let mapId, toX: let x, toY: let y):
                f = .portal(mapId: mapId, to: GridCoord(x, y))
            case .chest(id: let id, locked: let locked):
                f = .chest(id: id, locked: locked)
            case .trigger(id: let id):
                f = .trigger(id: id)
            case .note(text: let text):
                f = .note(text: text)
            case .lever(id: let id, isOn: let isOn):
                f = .lever(id: id, isOn: isOn)
            case .trap(id: let tid, detectDC: let det, disarmDC: let dis, damage: let dmg, once: let once, armed: let armed):
                f = .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: armed)
            }
            return Cell(terrain: terrain, walls: CellWalls(rawValue: walls), feature: f)
        }
    }

    static func encodeCells(_ cells: [Cell]) throws -> Data {
        try JSONEncoder().encode(cells.map(CellDTO.init(from:)))
    }
    static func decodeCells(_ data: Data) throws -> [Cell] {
        try JSONDecoder().decode([CellDTO].self, from: data).map { $0.toRuntime() }
    }
}
#endif
