//
//  StatBlock.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Generic, value-semantic stat container keyed by a `StatKey`.
public struct StatBlock<K: StatKey>: Sendable, Equatable {
    private var base: [K: Int] = [:]

    public init() {}
    public init(_ values: [K: Int]) { self.base = values }

    public subscript(_ key: K) -> Int {
        get { base[key, default: 0] }
        set { base[key] = newValue }
    }

    /// Add amount (can be negative) to a stat.
    public mutating func add(_ key: K, _ amount: Int) { self[key] = self[key] + amount }

    /// Merge another block by summing keyed values.
    public mutating func formUnion(_ other: StatBlock<K>) {
        for (k, v) in other.base { self[k] = self[k] + v }
    }

    public func union(_ other: StatBlock<K>) -> StatBlock<K> {
        var copy = self; copy.formUnion(other); return copy
    }
}

public extension StatBlock where K == CoreStat {
    /// Convenience accessors for common derived constraints (can evolve later).
    var maxHP: Int { max(1, self[.vit] * 10) }
    var maxMP: Int { max(0, self[.spi] * 5 + self[.int] * 3) }
}
