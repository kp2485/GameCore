//
//  GameSaveService.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import GameCore

// MARK: - Snapshot provider

/// Your app implements this to tell the service what to save.
@MainActor
public protocol GameStateProvider: Sendable {
    /// Party members in order (front to back, etc.)
    func currentPartyMembers() -> [Character]
    /// Equipment for a given member (nil = none).
    func equipment(for memberId: UUID) -> Equipment?
    /// Inventory (itemId -> quantity) for a given member (empty = none).
    func inventory(for memberId: UUID) -> [String: Int]
}

/// Convenience provider that you can build from closures.
@MainActor
public struct ClosureGameStateProvider: GameStateProvider {
    public let members: @Sendable () -> [Character]
    public let equipmentBy: @Sendable (_ id: UUID) -> Equipment?
    public let inventoryBy: @Sendable (_ id: UUID) -> [String: Int]

    public init(
        members: @escaping @Sendable () -> [Character],
        equipmentBy: @escaping @Sendable (_ id: UUID) -> Equipment? = { _ in nil },
        inventoryBy: @escaping @Sendable (_ id: UUID) -> [String: Int] = { _ in [:] }
    ) {
        self.members = members
        self.equipmentBy = equipmentBy
        self.inventoryBy = inventoryBy
    }

    public func currentPartyMembers() -> [Character] { members() }
    public func equipment(for memberId: UUID) -> Equipment? { equipmentBy(memberId) }
    public func inventory(for memberId: UUID) -> [String : Int] { inventoryBy(memberId) }
}

// MARK: - Loaded snapshot DTO

/// What you get back when loading a save.
public struct LoadedGame: Sendable {
    public let members: [Character]                      // ordered party
    public let equipmentById: [UUID: Equipment]          // per member
    public let inventoriesById: [UUID: [String: Int]]    // per member
    public let meta: GameSaveMeta

    public init(
        members: [Character],
        equipmentById: [UUID: Equipment],
        inventoriesById: [UUID: [String : Int]],
        meta: GameSaveMeta
    ) {
        self.members = members
        self.equipmentById = equipmentById
        self.inventoriesById = inventoriesById
        self.meta = meta
    }
}

// MARK: - Service

/// Facade over SDGameSaveRepository with a simple API for apps/UIs.
@MainActor
public final class GameSaveService: Sendable {
    private let repo: SDGameSaveRepository
    private let provider: GameStateProvider

    /// - Parameters:
    ///   - repo: SwiftData-backed repository (SDStack must include GameSave models).
    ///   - provider: Supplies the current in-memory party/equipment/inventory.
    public init(repo: SDGameSaveRepository, provider: GameStateProvider) {
        self.repo = repo
        self.provider = provider
    }

    // MARK: Save

    /// Snapshots the current party from the provider and persists it.
    /// - Returns: The newly created save ID.
    @discardableResult
    public func saveCurrentGame(name: String, notes: String? = nil) throws -> UUID {
        let members = provider.currentPartyMembers()

        // Build equipment/inventory maps keyed by member UUID
        var eq: [UUID: Equipment] = [:]
        var inv: [UUID: [String: Int]] = [:]
        for m in members {
            if let e = provider.equipment(for: m.id) { eq[m.id] = e }
            let bag = provider.inventory(for: m.id)
            if !bag.isEmpty { inv[m.id] = bag }
        }

        return try repo.saveGame(
            name: name,
            members: members,
            equipmentById: eq,
            inventoriesById: inv,
            notes: notes
        )
    }

    // MARK: Load

    /// Loads a specific save.
    public func loadGame(id: UUID) throws -> LoadedGame {
        let result = try repo.loadSave(id: id)
        return LoadedGame(
            members: result.members,
            equipmentById: result.equipmentById,
            inventoriesById: result.inventoriesById,
            meta: result.meta
        )
    }

    /// Loads the latest save (if any).
    public func loadLatestGame() throws -> LoadedGame? {
        guard let id = try repo.loadLatest() else { return nil }
        return try loadGame(id: id)
    }

    // MARK: Manage saves

    public func listSaves() throws -> [GameSaveMeta] {
        try repo.listSaves()
    }

    public func deleteSave(id: UUID) throws {
        try repo.deleteSave(id: id)
    }
}

// MARK: - Convenience helpers (optional)

public extension LoadedGame {
    /// Build a fresh Encounter from loaded members (HP/MP set to max).
    func asEncounter() -> Encounter<Character> {
        let allies = members.map { Combatant(base: $0, hp: $0.stats.maxHP) }
        return Encounter(allies: allies, foes: [])
    }
}

public extension CombatRuntime where A == Character {
    /// Apply loaded equipment map onto an existing runtime.
    mutating func applyEquipment(_ map: [UUID: Equipment]) {
        for (id, eq) in map { equipment[id] = eq }
    }
}
#endif
