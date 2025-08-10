//
//  Repositories.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public protocol RaceRepository: Sendable {
    func allRaces() throws -> [Race]
    func race(id: String) throws -> Race?
}

public protocol ClassRepository: Sendable {
    func allClasses() throws -> [ClassDef]
    func `class`(id: String) throws -> ClassDef?
}

public struct InMemoryRaceRepository: RaceRepository, Sendable {
    private let races: [String: Race]
    public init(_ list: [Race]) {
        self.races = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }
    public func allRaces() throws -> [Race] { Array(races.values) }
    public func race(id: String) throws -> Race? { races[id] }
}

public struct InMemoryClassRepository: ClassRepository, Sendable {
    private let classes: [String: ClassDef]
    public init(_ list: [ClassDef]) {
        self.classes = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }
    public func allClasses() throws -> [ClassDef] { Array(classes.values) }
    public func `class`(id: String) throws -> ClassDef? { classes[id] }
}

// Optional app-wide environment for tests and later dependency injection.
public struct GameEnvironment: Sendable {
    public var races: any RaceRepository
    public var classes: any ClassRepository
    public init(races: any RaceRepository, classes: any ClassRepository) {
        self.races = races
        self.classes = classes
    }
}
