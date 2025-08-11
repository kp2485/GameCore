//
//  MapService.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData) && canImport(GameMap)
import Foundation
import GameCore
import GameMap

@MainActor
public final class MapService: Sendable {
    private let maps: SDMapRepository
    private let saveId: UUID
    private(set) public var runtime: MapRuntime?

    public init(maps: SDMapRepository, saveId: UUID) {
        self.maps = maps
        self.saveId = saveId
    }

    /// Load a map by id and build a runtime at a given start.
    /// Regions are now read from persistence.
    public func load(mapId: String, start: GridCoord, facing: Direction = .north) throws {
        guard let map = try maps.fetchMap(id: mapId) else { throw SwiftDataError.missingRecord }
        let tiles = map.width * map.height
        let bitset = try maps.loadFog(saveId: saveId, mapId: map.id, tiles: tiles)
        let fogSet = FogBitsDecode.indices(bitset: bitset, width: map.width, height: map.height)
        runtime = MapRuntime(map: map, start: start, facing: facing, fog: fogSet)
    }

    @discardableResult
    public func revealCurrentFOV(radius: Int) throws -> Set<GridCoord> {
        guard var rt = runtime else { return [] }
        let before = rt.fog
        _ = rt.revealFOV(radius: radius)
        runtime = rt
        _ = try persistFogUnion()
        return rt.fog.subtracting(before)
    }

    @discardableResult
    public func moveForward(rng: inout any Randomizer, autoRevealRadius: Int? = nil) throws -> MovementResult {
        guard var rt = runtime else {
            return MovementResult(moved: false, position: GridCoord(0,0), facing: .north, triggeredEncounterId: nil)
        }
        let res = rt.moveForward(rng: &rng)
        if res.moved, let r = autoRevealRadius { _ = rt.revealFOV(radius: r) }
        runtime = rt
        if res.moved { _ = try persistFogUnion() }
        return res
    }

    // MARK: - Private

    @discardableResult
    private func persistFogUnion() throws -> Data {
        guard let rt = runtime else { return Data() }
        let tiles = rt.map.width * rt.map.height
        var current = FogBits.makeEmpty(count: tiles)
        for p in rt.fog {
            let idx = p.y * rt.map.width + p.x
            FogBits.set(&current, index: idx)
        }
        return try maps.mergeFog(saveId: saveId, mapId: rt.map.id, additional: current)
    }
}

enum FogBitsDecode {
    static func indices(bitset: Data, width: Int, height: Int) -> Set<GridCoord> {
        var out: Set<GridCoord> = []
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if FogBits.isSet(bitset, index: idx) {
                    out.insert(GridCoord(x, y))
                }
            }
        }
        return out
    }
}
#endif
