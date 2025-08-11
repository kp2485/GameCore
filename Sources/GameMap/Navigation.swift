//
//  Navigation.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Helpers for edge-accurate movement rules on `GameMap`.
public enum Navigation {
    
    /// Returns `true` if movement across the edge from `a` toward `dir` is blocked.
    /// An edge is blocked if:
    /// - Either tile places a wall on that shared edge, or
    /// - The destination tile contains a door feature (locked/secret/any door variant), or
    /// - The destination is out of bounds.
    public static func edgeBlocked(from a: GridCoord, toward dir: Direction, on map: GameMap) -> Bool {
        guard let b = map.neighbor(of: a, toward: dir) else { return true }
        
        // Walls placed on either side of the shared edge block.
        let aw: CellWalls = map[a].walls
        let bw: CellWalls = map[b].walls
        if aw.contains(wallFor(dir)) { return true }
        if bw.contains(wallFor(opposite(of: dir))) { return true }
        
        // NEW: secret edge/door presence blocks until revealed.
        if aw.contains(.secret) { return true }
        if bw.contains(.secret) { return true }
        
        // Doors on either side block until opened (feature becomes .none).
        switch map[a].feature {
        case .door: return true
        default: break
        }
        switch map[b].feature {
        case .door: return true
        default: break
        }
        
        return false
    }
    
    /// Can we move a full step from `a` toward `dir` (i.e., across the edge and into the tile)?
    public static func canMove(from a: GridCoord, toward dir: Direction, on map: GameMap) -> Bool {
        guard let b = map.neighbor(of: a, toward: dir) else { return false }
        if edgeBlocked(from: a, toward: dir, on: map) { return false }
        
        // If destination tile still has a blocking feature, disallow (redundant with edgeBlocked’s door check,
        // but keeps room for future blocking features).
        switch map[b].feature {
        case .door: return false
        default:    return true
        }
    }
    
    // MARK: - Private helpers
    
    /// Map a facing to its wall bit on the *origin* tile.
    @inline(__always)
    private static func wallFor(_ dir: Direction) -> CellWalls {
        switch dir {
        case .north: return .north
        case .east:  return .east
        case .south: return .south
        case .west:  return .west
        }
    }
    
    /// Opposite cardinal.
    @inline(__always)
    private static func opposite(of dir: Direction) -> Direction {
        switch dir {
        case .north: return .south
        case .east:  return .west
        case .south: return .north
        case .west:  return .east
        }
    }
}
