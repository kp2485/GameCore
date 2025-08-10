//
//  Randomizer.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Deterministic RNG protocol to make the rules engine testable.
public protocol Randomizer: Sendable {
    mutating func next() -> UInt64
    mutating func uniform(_ upperBound: UInt64) -> UInt64
}

/// A simple SplitMix64 RNG: fast, good equidistribution, reproducible.
public struct SeededPRNG: Randomizer, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func uniform(_ upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0, "upperBound must be > 0")
        // Rejection sampling to avoid modulo bias.
        let threshold = (0 &- upperBound) % upperBound
        while true {
            let r = next()
            if r >= threshold { return r % upperBound }
        }
    }
}
