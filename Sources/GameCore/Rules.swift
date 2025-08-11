//
//  Rules.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/11/25.
//

import Foundation

public struct GameRules: Sendable, Equatable {
    public var attackVarianceMax: UInt64 = 2
    public var maxMitigationPercent: Int = 80

    // NEW: hit chance tunables
    public var baseHitPercent: Int = 70          // baseline chance to hit
    public var spdSlopePerPoint: Int = 3         // each SPD diff point shifts hit chance by this
    public var minHitPercent: Int = 5            // clamp floor
    public var maxHitPercent: Int = 95           // clamp ceiling

    public init(
        attackVarianceMax: UInt64 = 2,
        maxMitigationPercent: Int = 80,
        baseHitPercent: Int = 70,
        spdSlopePerPoint: Int = 3,
        minHitPercent: Int = 5,
        maxHitPercent: Int = 95
    ) {
        self.attackVarianceMax = attackVarianceMax
        self.maxMitigationPercent = max(0, min(100, maxMitigationPercent))
        self.baseHitPercent = baseHitPercent
        self.spdSlopePerPoint = spdSlopePerPoint
        self.minHitPercent = max(0, min(100, minHitPercent))
        self.maxHitPercent = max(0, min(100, maxHitPercent))
    }

    public static let `default` = GameRules()
}
