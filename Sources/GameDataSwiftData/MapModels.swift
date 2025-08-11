//
//  MapModels.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData

/// A persisted map with all its cells encoded as a blob (versioned JSON for now).
@Model
public final class MapEntity {
    @Attribute(.unique) public var id: String
    public var name: String
    public var width: Int
    public var height: Int
    public var cellsBlob: Data          // encoded cells
    public var codecVersion: Int        // cells codec version

    // NEW: regions blob (optional for backward compatibility) + version
    public var regionsBlob: Data?
    public var regionsCodecVersion: Int?

    public init(
        id: String,
        name: String,
        width: Int,
        height: Int,
        cellsBlob: Data,
        codecVersion: Int,
        regionsBlob: Data? = nil,
        regionsCodecVersion: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.cellsBlob = cellsBlob
        self.codecVersion = codecVersion
        self.regionsBlob = regionsBlob
        self.regionsCodecVersion = regionsCodecVersion
    }
}

/// Per-save, per-map fog-of-war bitset (1 bit per tile).
@Model
public final class SaveFogEntity {
    @Attribute(.unique) public var key: String   // "\(saveId.uuidString)|\(mapId)"
    public var saveId: UUID
    public var mapId: String
    public var bitset: Data

    public init(saveId: UUID, mapId: String, bitset: Data) {
        self.saveId = saveId
        self.mapId = mapId
        self.bitset = bitset
        self.key = "\(saveId.uuidString)|\(mapId)"
    }
}
#endif
