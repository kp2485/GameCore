//
//  Pathfinding.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public enum Pathfinder {
    public static func aStar(from start: GridCoord, to goal: GridCoord, on map: GameMap, passable: (GridCoord) -> Bool) -> [GridCoord] {
        struct Node: Hashable { let p: GridCoord }
        func h(_ a: GridCoord, _ b: GridCoord) -> Int { abs(a.x - b.x) + abs(a.y - b.y) }

        var open: Set<Node> = [Node(p: start)]
        var came: [GridCoord: GridCoord] = [:]
        var g: [GridCoord: Int] = [start: 0]
        var f: [GridCoord: Int] = [start: h(start, goal)]

        while let current = open.min(by: { (f[$0.p] ?? .max) < (f[$1.p] ?? .max) }) {
            let cp = current.p
            if cp == goal {
                var path: [GridCoord] = [goal]
                var cur = goal
                while let prev = came[cur] { path.append(prev); cur = prev }
                return path.reversed()
            }
            open.remove(current)

            for n in neighbors(of: cp, on: map) where passable(n) {
                let tentative = (g[cp] ?? .max/2) + 1
                if tentative < (g[n] ?? .max) {
                    came[n] = cp
                    g[n] = tentative
                    f[n] = tentative + h(n, goal)
                    open.insert(Node(p: n))
                }
            }
        }
        return []
    }

    private static func neighbors(of p: GridCoord, on map: GameMap) -> [GridCoord] {
        let ns = [
            GridCoord(p.x, p.y - 1),
            GridCoord(p.x + 1, p.y),
            GridCoord(p.x, p.y + 1),
            GridCoord(p.x - 1, p.y)
        ]
        return ns.filter { map.inBounds($0) }
    }
}
