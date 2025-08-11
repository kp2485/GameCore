//
//  LOS.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public enum LOS {
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

    /// Edge-accurate FOV: a tile is visible if **no blocked edge** lies on any ray from `origin`,
    /// EXCEPT we still allow the **final edge into the target tile** to be blocked (you can see the wall face).
    public static func visible(from origin: GridCoord, radius: Int, on map: GameMap) -> Set<GridCoord> {
        var vis: Set<GridCoord> = [origin]
        guard radius > 0 else { return vis }

        let minY = max(0, origin.y - radius), maxY = min(map.height - 1, origin.y + radius)
        let minX = max(0, origin.x - radius), maxX = min(map.width - 1, origin.x + radius)

        for y in minY...maxY {
            for x in minX...maxX {
                let p = GridCoord(x, y)
                if abs(x - origin.x) + abs(y - origin.y) > radius { continue }

                let ray = line(from: origin, to: p)
                var blockedBeforeTarget = false
                if ray.count >= 2 {
                    // Examine edges; allow the **last** edge (into p) to be blocked.
                    for i in 1..<ray.count {
                        let a = ray[i - 1], b = ray[i]
                        guard let dir = stepDirection(from: a, to: b) else { continue }
                        if Navigation.edgeBlocked(from: a, toward: dir, on: map) {
                            // If this is NOT the final edge into the target, visibility is blocked.
                            if i < ray.count - 1 {
                                blockedBeforeTarget = true
                            }
                            break
                        }
                    }
                }
                if !blockedBeforeTarget { vis.insert(p) }
            }
        }
        return vis
    }

    @inline(__always)
    private static func stepDirection(from a: GridCoord, to b: GridCoord) -> Direction? {
        if b.x == a.x && b.y == a.y - 1 { return .north }
        if b.x == a.x + 1 && b.y == a.y { return .east }
        if b.x == a.x && b.y == a.y + 1 { return .south }
        if b.x == a.x - 1 && b.y == a.y { return .west }
        return nil
    }
}
