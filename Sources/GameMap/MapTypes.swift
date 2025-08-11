//
//  MapTypes.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public struct GridCoord: Hashable, Sendable, Codable, CustomStringConvertible {
    public let x: Int
    public let y: Int
    @inlinable public init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
    public var description: String { "(\(x),\(y))" }
}

public enum Direction: CaseIterable, Sendable {
    case north, east, south, west

    public var dx: Int { self == .east ? 1 : self == .west ? -1 : 0 }
    public var dy: Int { self == .south ? 1 : self == .north ? -1 : 0 }

    public func turnLeft() -> Direction {
        switch self { case .north: return .west; case .west: return .south; case .south: return .east; case .east: return .north }
    }
    public func turnRight() -> Direction {
        switch self { case .north: return .east; case .east: return .south; case .south: return .west; case .west: return .north }
    }
    public var opposite: Direction {
        switch self { case .north: return .south; case .east: return .west; case .south: return .north; case .west: return .east }
    }
}

public struct CellWalls: OptionSet, Sendable, Codable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let north = CellWalls(rawValue: 1 << 0)
    public static let east  = CellWalls(rawValue: 1 << 1)
    public static let south = CellWalls(rawValue: 1 << 2)
    public static let west  = CellWalls(rawValue: 1 << 3)
    public static let secret = CellWalls(rawValue: 1 << 4) // marker for secret walls/doors
}

public enum Feature: Sendable, Codable, Hashable {
    case none
    case door(locked: Bool, secret: Bool, lockDC: Int? = nil, lockSkill: String? = nil)
    case stairsUp
    case stairsDown
    case portal(mapId: String, to: GridCoord)
    case chest(id: String, locked: Bool)
    case trigger(id: String)
    case note(text: String)
    case lever(id: String, isOn: Bool)
    case trap(id: String, detectDC: Int, disarmDC: Int, damage: Int, once: Bool, armed: Bool)
}

public struct Cell: Sendable, Codable, Hashable {
    public var terrain: UInt8            // room/corridor/water/lava/etc.
    public var walls: CellWalls
    public var feature: Feature
    public init(terrain: UInt8 = 0, walls: CellWalls = [], feature: Feature = .none) {
        self.terrain = terrain
        self.walls = walls
        self.feature = feature
    }
}

public struct Rect: Sendable, Codable, Hashable {
    public var x, y, w, h: Int
    public init(x: Int, y: Int, w: Int, h: Int) { self.x = x; self.y = y; self.w = w; self.h = h }
    public func contains(_ p: GridCoord) -> Bool { p.x >= x && p.y >= y && p.x < x + w && p.y < y + h }
}

public struct MapRegion: Sendable, Codable, Hashable {
    public var rects: [Rect]
    public var encounter: EncounterTable?
    public init(rects: [Rect], encounter: EncounterTable? = nil) {
        self.rects = rects
        self.encounter = encounter
    }
    public func contains(_ p: GridCoord) -> Bool { rects.contains { $0.contains(p) } }
}

public struct GameMap: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let width: Int
    public let height: Int
    public private(set) var cells: [Cell]           // row-major: y*width + x
    public var regions: [String: MapRegion]         // name → region

    public init(id: String, name: String, width: Int, height: Int, fill: Cell = Cell(), regions: [String: MapRegion] = [:]) {
        precondition(width > 0 && height > 0, "Map must have positive dimensions")
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.cells = Array(repeating: fill, count: width * height)
        self.regions = regions
    }

    @inline(__always) public func inBounds(_ p: GridCoord) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
    }
    @inline(__always) public func index(_ p: GridCoord) -> Int { p.y * width + p.x }

    public subscript(_ p: GridCoord) -> Cell {
        get { cells[index(p)] }
        set { cells[index(p)] = newValue }
    }

    public func neighbor(of p: GridCoord, toward dir: Direction) -> GridCoord? {
        let n = GridCoord(p.x + dir.dx, p.y + dir.dy)
        return inBounds(n) ? n : nil
    }
}
