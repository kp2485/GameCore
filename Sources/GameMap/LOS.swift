//
//  LOS.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public enum LOS {
    /// Bresenham line between two tiles (inclusive).
    public static func line(from a: GridCoord, to b: GridCoord) -> [GridCoord] {
        var points: [GridCoord] = []
        var x0 = a.x, y0 = a.y, x1 = b.x, y1 = b.y
        let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
        let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            points.append(GridCoord(x0, y0))
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
        return points
    }

    /// Simple FOV with radius. Treats any tile with *any* wall as opaque.
    /// (We can refine to edge-accurate later.)
    public static func visible(from origin: GridCoord, radius: Int, on map: GameMap) -> Set<GridCoord> {
        var vis: Set<GridCoord> = [origin]
        guard radius > 0 else { return vis }
        let r2 = radius * radius

        let minY = max(0, origin.y - radius), maxY = min(map.height - 1, origin.y + radius)
        let minX = max(0, origin.x - radius), maxX = min(map.width - 1, origin.x + radius)

        for y in minY...maxY {
            for x in minX...maxX {
                let p = GridCoord(x, y)
                let dx = x - origin.x, dy = y - origin.y
                if dx*dx + dy*dy > r2 { continue }
                // raycast; stop at solid tiles
                var blocked = false
                for step in line(from: origin, to: p) {
                    if step != origin && isOpaque(step, on: map) { blocked = true; break }
                }
                if !blocked { vis.insert(p) }
            }
        }
        return vis
    }

    private static func isOpaque(_ p: GridCoord, on map: GameMap) -> Bool {
        guard map.inBounds(p) else { return true }
        return !map[p].walls.isEmpty
    }
}
