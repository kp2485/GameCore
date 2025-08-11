//
//  Event.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Lightweight log event for determinism & later replay.
public struct Event: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case turnStart, action, damage, heal, statusApplied, statusExpired, death, note, xpGained, levelUp, goldAwarded, lootDropped, shopBuy, shopSell }
    public let kind: Kind
    public let timestamp: UInt64 // deterministic tick or frame; for now, just monotonic counter
    public let data: [String: String]

    public init(kind: Kind, timestamp: UInt64, data: [String: String] = [:]) {
        self.kind = kind; self.timestamp = timestamp; self.data = data
    }
}
