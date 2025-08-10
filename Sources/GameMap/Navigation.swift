//
//  Navigation.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Basic passability rules for movement between neighboring tiles.
public enum Navigation {
    /// Returns true if you can move from `p` toward `dir` given map cell walls/features.
    public static func canMove(from p: GridCoord, toward dir: Direction, on map: GameMap) -> Bool {
        guard map.inBounds(p), let q = map.neighbor(of: p, toward: dir) else { return false }
        let a = map[p]
        let b = map[q]

        // Solid walls block (either side)
        if a.walls.contains(wallFlag(for: dir)) { return false }
        if b.walls.contains(wallFlag(for: dir.opposite)) { return false }

        // Locked door blocks at either side
        if isLockedDoor(a.feature) && (dir == .north || dir == .east || dir == .south || dir == .west) { return false }
        if isLockedDoor(b.feature) { return false }

        return true
    }

    @inline(__always)
    private static func wallFlag(for dir: Direction) -> CellWalls {
        switch dir {
        case .north: return .north
        case .east:  return .east
        case .south: return .south
        case .west:  return .west
        }
    }

    @inline(__always)
    private static func isLockedDoor(_ f: Feature) -> Bool {
        if case let .door(locked, _) = f { return locked }
        return false
    }
}
