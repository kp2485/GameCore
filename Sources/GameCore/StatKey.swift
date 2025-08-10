//
//  StatKey.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Marker for the set of stats used in a game. Typically an enum per game.
public protocol StatKey: Hashable, Sendable, CaseIterable {}

/// Default Fizzle core stats; adjust as needed in later milestones.
public enum CoreStat: String, CaseIterable, StatKey {
    case str, vit, agi, int, spi, luc
    case hp, mp
    case spd, acc, eva
}
