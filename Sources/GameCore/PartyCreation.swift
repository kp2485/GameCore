//
//  PartyCreation.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public struct CreationSpec: Sendable, Hashable {
    public let name: String
    public let raceId: String
    public let classId: String
    /// Player-allocated base stats (before race bonuses). You may omit primaries;
    /// omitted primaries will default to `rules.minPerStat`.
    public let baseStats: [CoreStat: Int]

    public init(name: String, raceId: String, classId: String, baseStats: [CoreStat: Int]) {
        self.name = name
        self.raceId = raceId
        self.classId = classId
        self.baseStats = baseStats
    }
}

public enum CreationError: Error, CustomStringConvertible, Sendable {
    case unknownRace(String)
    case unknownClass(String)
    case statBelowRequirement(stat: CoreStat, have: Int, need: Int)
    case totalPointsExceeded(allowed: Int, got: Int)
    case invalidName

    public var description: String {
        switch self {
        case .unknownRace(let r): return "Unknown race: \(r)"
        case .unknownClass(let c): return "Unknown class: \(c)"
        case .statBelowRequirement(let k, let have, let need): return "Requirement not met: \(k) need \(need) have \(have)"
        case .totalPointsExceeded(let allowed, let got): return "Allocated \(got) but only \(allowed) allowed"
        case .invalidName: return "Invalid character name"
        }
    }
}

/// Rules for character creation.
/// `minPerStat`/`maxPerStat` apply to **primary** attributes only (str, vit, agi, int, spi, luc).
public struct CreationRules: Sendable {
    public let startingPoints: Int
    public let minPerStat: Int
    public let maxPerStat: Int

    public init(startingPoints: Int = 30, minPerStat: Int = 1, maxPerStat: Int = 18) {
        self.startingPoints = startingPoints
        self.minPerStat = minPerStat
        self.maxPerStat = maxPerStat
    }
}

public struct PartyBuilder: Sendable {
    public let env: GameEnvironment
    public let rules: CreationRules

    public init(env: GameEnvironment, rules: CreationRules = CreationRules()) {
        self.env = env
        self.rules = rules
    }

    /// Primary attribute keys (subject to min/max and class requirements).
    private var primaryKeys: [CoreStat] { [.str, .vit, .agi, .int, .spi, .luc] }

    public func buildCharacter(from spec: CreationSpec) throws -> Character {
        // Identity
        guard !spec.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw CreationError.invalidName }

        // Lookups
        guard let race = try env.races.race(id: spec.raceId)
        else { throw CreationError.unknownRace(spec.raceId) }
        guard let klass = try env.classes.class(id: spec.classId)
        else { throw CreationError.unknownClass(spec.classId) }

        // 1) Validate point budget on the **base** allocation (only for provided entries)
        //    Note: omitted primaries will default later; they do NOT count toward budget here.
        let totalAllocated = spec.baseStats
            .filter { primaryKeys.contains($0.key) }
            .map(\.value)
            .reduce(0, +)
        if totalAllocated > rules.startingPoints {
            throw CreationError.totalPointsExceeded(allowed: rules.startingPoints, got: totalAllocated)
        }

        // 2) Build final stats:
        //    - For primaries: default omitted to minPerStat, then add race bonuses.
        //    - For secondaries: start at 0; we'll set hp/mp after.
        var stats = StatBlock<CoreStat>()
        for k in primaryKeys {
            let base = spec.baseStats[k] ?? rules.minPerStat
            let bonus = race.statBonuses[k] ?? 0
            stats[k] = base + bonus
        }
        // Ensure non-primary keys start at 0 for now
        for k in CoreStat.allCases where !primaryKeys.contains(k) {
            stats[k] = 0
        }

        // 3) Enforce per-stat min/max on **final primary** stats only
        for k in primaryKeys {
            let v = stats[k]
            if v < rules.minPerStat {
                throw CreationError.statBelowRequirement(stat: k, have: v, need: rules.minPerStat)
            }
            if v > rules.maxPerStat {
                throw CreationError.statBelowRequirement(stat: k, have: v, need: rules.maxPerStat)
            }
        }

        // 4) Enforce class requirements on final stats (after bonuses)
        for (k, need) in klass.minStats {
            let have = stats[k]
            if have < need {
                throw CreationError.statBelowRequirement(stat: k, have: have, need: need)
            }
        }

        // 5) Initialize derived resources AFTER validation
        //    HP/MP are derived from primaries; start current values at max.
        stats[.hp] = stats.maxHP
        stats[.mp] = stats.maxMP

        // 6) Compose tags (race + class)
        var tags = race.tags.union(klass.startingTags)
        tags.insert("class:\(klass.id)")
        tags.insert("race:\(race.id)")

        return Character(name: spec.name, stats: stats, tags: tags)
    }

    public func buildParty(from specs: [CreationSpec]) throws -> Party<Character> {
        let members = try specs.map { try buildCharacter(from: $0) }
        return Party(members)
    }
}
