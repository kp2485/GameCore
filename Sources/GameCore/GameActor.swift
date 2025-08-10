//
//  GameActor.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public protocol GameActor: Identifiable, Sendable, Hashable {
    associatedtype K: StatKey
    var id: UUID { get }
    var name: String { get }
    var stats: StatBlock<K> { get set }
    var tags: Set<String> { get }
}

public extension GameActor {
    static func ==(lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
