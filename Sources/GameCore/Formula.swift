//
//  Formula.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Central place for combat math. Keep pure & testable.

public enum Formula: Sendable {
    public static func finalDamage(base: Int, mitigationPercent: Int) -> Int {
        let clamped = max(0, min(100, mitigationPercent))
        let reduced = base * (100 - clamped) / 100
        return max(0, reduced)
    }

    /// Combine status-based mitigation with armor mitigation (cap at 80% total for now).
    public static func combinedMitigation(statusPct: Int, armorPct: Int) -> Int {
        min(80, max(0, statusPct) + max(0, armorPct))
    }
}
