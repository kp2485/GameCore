//
//  RepositoriesSwiftData.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import SwiftData
import GameCore

public enum SwiftDataError: Error { case missingRecord, duplicateID }

/// Keep SwiftData on the main actor (matches Apple’s guidance).
@MainActor
public final class SDStack {
    public let container: ModelContainer
    public init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        // IMPORTANT: include ALL models used by this container
        self.container = try ModelContainer(
            for: RaceEntity.self, ClassEntity.self, CharacterEntity.self,
                ItemEntity.self, EquipmentSlotEntity.self,
                GameSaveEntity.self, PartyMemberEntity.self, SaveEquipmentSlotEntity.self, SaveInventoryItemEntity.self,
                MapEntity.self, SaveFogEntity.self, ShopEntity.self, ShopOfferEntity.self,
            configurations: config
        )
    }
    public var context: ModelContext { ModelContext(container) }
}

// MARK: - RaceRepository (sync API, runs on MainActor)

public struct SDRaceRepository: @preconcurrency RaceRepository, Sendable {
    @MainActor private let stack: SDStack
    public init(stack: SDStack) { self.stack = stack }
    
    @MainActor
    public func allRaces() throws -> [Race] {
        let ctx = stack.context
        let fd = FetchDescriptor<RaceEntity>(sortBy: [SortDescriptor(\.name)])
        let rows = try ctx.fetch(fd)
        return rows.map(Race.init)
    }
    
    @MainActor
    public func race(id: String) throws -> Race? {
        let ctx = stack.context
        let rid = id // bind to a local constant for #Predicate capture
        var fd = FetchDescriptor<RaceEntity>(predicate: #Predicate { $0.id == rid })
        fd.fetchLimit = 1
        return try ctx.fetch(fd).first.map(Race.init)
    }
    
    // Seeder/helper
    @MainActor
    public func upsert(_ race: Race) throws {
        let ctx = stack.context
        let rid = race.id
        var fd = FetchDescriptor<RaceEntity>(predicate: #Predicate { $0.id == rid })
        fd.fetchLimit = 1
        if let existing = try ctx.fetch(fd).first {
            existing.name = race.name
            existing.statBonuses = DictStatsCodec.encode(race.statBonuses)
            existing.tags = Array(race.tags)
        } else {
            ctx.insert(RaceEntity(
                id: race.id,
                name: race.name,
                statBonuses: DictStatsCodec.encode(race.statBonuses),
                tags: Array(race.tags)
            ))
        }
        try ctx.save()
    }
}

// MARK: - ClassRepository (sync API, runs on MainActor)

public struct SDClassRepository: @preconcurrency ClassRepository, Sendable {
    @MainActor private let stack: SDStack
    public init(stack: SDStack) { self.stack = stack }
    
    @MainActor
    public func allClasses() throws -> [ClassDef] {
        let ctx = stack.context
        let fd = FetchDescriptor<ClassEntity>(sortBy: [SortDescriptor(\.name)])
        let rows = try ctx.fetch(fd)
        return rows.map(ClassDef.init)
    }
    
    @MainActor
    public func `class`(id: String) throws -> ClassDef? {
        let ctx = stack.context
        let cid = id
        var fd = FetchDescriptor<ClassEntity>(predicate: #Predicate { $0.id == cid })
        fd.fetchLimit = 1
        return try ctx.fetch(fd).first.map(ClassDef.init)
    }
    
    @MainActor
    public func upsert(_ cls: ClassDef) throws {
        let ctx = stack.context
        let cid = cls.id
        var fd = FetchDescriptor<ClassEntity>(predicate: #Predicate { $0.id == cid })
        fd.fetchLimit = 1
        if let existing = try ctx.fetch(fd).first {
            existing.name = cls.name
            existing.minStats = DictStatsCodec.encode(cls.minStats)
            existing.allowedWeapons = Array(cls.allowedWeapons)
            existing.allowedArmor = Array(cls.allowedArmor)
            existing.startingTags = Array(cls.startingTags)
            existing.startingLevel = cls.startingLevel
        } else {
            ctx.insert(ClassEntity(
                id: cls.id,
                name: cls.name,
                minStats: DictStatsCodec.encode(cls.minStats),
                allowedWeapons: Array(cls.allowedWeapons),
                allowedArmor: Array(cls.allowedArmor),
                startingTags: Array(cls.startingTags),
                startingLevel: cls.startingLevel
            ))
        }
        try ctx.save()
    }
}

// MARK: - Character store (sync API, runs on MainActor)

public protocol CharacterStore: Sendable {
    func save(_ c: Character) throws -> UUID
    func fetchAll() throws -> [(id: UUID, character: Character)]
    func delete(id: UUID) throws
}

public struct SDCharacterStore: @preconcurrency CharacterStore, Sendable {
    @MainActor private let stack: SDStack
    public init(stack: SDStack) { self.stack = stack }
    
    @MainActor
    public func save(_ c: Character) throws -> UUID {
        let ctx = stack.context
        let e = CharacterEntity(
            name: c.name,
            stats: StatsCodec.encode(c.stats),
            tags: Array(c.tags)
        )
        ctx.insert(e)
        try ctx.save()
        return e.uuid
    }
    
    @MainActor
    public func fetchAll() throws -> [(id: UUID, character: Character)] {
        let ctx = stack.context
        let fd = FetchDescriptor<CharacterEntity>(sortBy: [SortDescriptor(\.createdAt)])
        return try ctx.fetch(fd).map { ($0.uuid, Character($0)) }
    }
    
    @MainActor
    public func delete(id: UUID) throws {
        let ctx = stack.context
        let target = id
        var fd = FetchDescriptor<CharacterEntity>(predicate: #Predicate { $0.uuid == target })
        fd.fetchLimit = 1
        if let row = try ctx.fetch(fd).first {
            ctx.delete(row)
            try ctx.save()
        }
    }
}
#endif
