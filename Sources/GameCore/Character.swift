//
//  Character.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Minimal playable character for Milestone 1.
public struct Character: GameActor, Sendable {
    public typealias K = CoreStat
    public let id: UUID
    public var name: String
    public var stats: StatBlock<CoreStat>
    public var tags: Set<String>

    public init(id: UUID = UUID(), name: String, stats: StatBlock<CoreStat>, tags: Set<String> = []) {
        self.id = id
        self.name = name
        self.stats = stats
        self.tags = tags
    }
}
