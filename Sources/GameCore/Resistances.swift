//
//  Resistances.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public enum Element: String, Sendable, Codable, CaseIterable {
    case physical, fire, ice, poison
}

public enum ResistanceSystem {
    /// Reads tags like "resist:fire=25" (0...100). Unknown or malformed → 0.
    public static func percent<A: GameActor>(for element: Element, actor: A) -> Int {
        guard !actor.tags.isEmpty else { return 0 }
        // Tags are a Set<String> on Character; for generic A, assume String-like tags via CustomStringConvertible.
        // Most code uses plain String, so this cast is safe in your codebase.
        for raw in actor.tags {
            // Expected shapes: "resist:fire=25", case-insensitive element
            if raw.lowercased().hasPrefix("resist:\(element.rawValue)=") {
                if let valStr = raw.split(separator: "=").last,
                   let pct = Int(valStr) {
                    return max(0, min(100, pct))
                }
            }
        }
        return 0
    }
}
