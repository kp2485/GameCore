//
//  Skills.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// MARK: - Domains & IDs

public enum SkillDomain: String, Codable, Sendable, CaseIterable, Hashable {
    case combat, magic, stealth, lore, survival, social, crafting, misc
}

/// Stable identifier for a skill (e.g., "sword", "fire_magic")
public struct SkillID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ s: String) { self.rawValue = s }
    public var description: String { rawValue }
}

// MARK: - Definitions (catalog models)

/// Metadata about a skill (domain, display name, optional governing stat)
public struct SkillDef<K: Hashable & Codable & Sendable>: Codable, Sendable, Hashable {
    public let id: SkillID
    public let name: String
    public let domain: SkillDomain
    /// If you want stats to influence caps, difficulty, etc.
    public let governingStat: K?
    /// Max trainable ranks (bonuses can exceed this for situational effects)
    public let maxRanks: Int
    public let description: String?

    public init(
        id: SkillID,
        name: String,
        domain: SkillDomain,
        governingStat: K? = nil,
        maxRanks: Int = 100,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.governingStat = governingStat
        self.maxRanks = maxRanks
        self.description = description
    }
}

/// A simple, type-erased catalog so Gameplay code can look up defs without knowing stat key type.
public struct AnySkillDef: Codable, Sendable, Hashable {
    public let id: SkillID
    public let name: String
    public let domain: SkillDomain
    public let maxRanks: Int
    public let description: String?

    public init<K>(_ def: SkillDef<K>) {
        self.id = def.id
        self.name = def.name
        self.domain = def.domain
        self.maxRanks = def.maxRanks
        self.description = def.description
    }
}

/// A small catalog that maps SkillID → definition. (You can build one per game.)
public struct SkillCatalog: Codable, Sendable, Equatable {
    public var defs: [SkillID: AnySkillDef]
    public init(defs: [SkillID: AnySkillDef] = [:]) { self.defs = defs }

    public subscript(_ id: SkillID) -> AnySkillDef? { defs[id] }
    public mutating func register(_ def: AnySkillDef) { defs[def.id] = def }
}

// MARK: - Sheets & math

/// Holds a character’s skill ranks and situational bonuses.
/// Neutral about your actor type so you can pair it with any GameActor externally.
public struct SkillSheet: Codable, Sendable, Equatable {
    /// Permanent ranks (0...def.maxRanks typically)
    public var ranks: [SkillID: Int]
    /// Temporary modifiers (equipment, buffs, terrain, stance)
    public var bonuses: [SkillID: Int]

    public init(ranks: [SkillID: Int] = [:], bonuses: [SkillID: Int] = [:]) {
        self.ranks = ranks
        self.bonuses = bonuses
    }

    public func rank(of id: SkillID) -> Int { max(0, ranks[id] ?? 0) }
    public func bonus(of id: SkillID) -> Int { bonuses[id] ?? 0 }

    /// Total = clamped ranks + bonus (bonus can exceed caps if you want).
    public func total(of id: SkillID, using catalog: SkillCatalog?) -> Int {
        let r = rank(of: id)
        if let maxR = catalog?.defs[id]?.maxRanks {
            return min(r, maxR) + bonus(of: id)
        } else {
            return r + bonus(of: id)
        }
    }

    public mutating func addRanks(_ id: SkillID, _ delta: Int, using catalog: SkillCatalog?) {
        var r = rank(of: id) + delta
        if let maxR = catalog?.defs[id]?.maxRanks { r = max(0, min(r, maxR)) }
        ranks[id] = r
    }

    public mutating func addBonus(_ id: SkillID, _ delta: Int) {
        bonuses[id] = (bonuses[id] ?? 0) + delta
    }
    
    public mutating func setBonus(_ id: SkillID, _ value: Int) {
        bonuses[id] = value
    }
}

// MARK: - Checks

public enum SkillOutcome: Sendable, Equatable {
    case fumble(roll: Int)
    case fail(roll: Int, margin: Int)     // how much over DC you were
    case success(roll: Int, margin: Int)  // how much you beat the DC by
    case critical(roll: Int)
}

/// A simple d100 roll-under system with DC:
/// - Roll 0...99 inclusive.
/// - Critical on <= 2 (configurable), fumble on >= 97 (configurable).
/// - Succeeds if (roll <= total - (DC-50)) equivalently: total - roll >= DC - 50
public struct SkillCheckConfig: Sendable, Equatable {
    public var criticalUnder: Int = 2   // 0,1,2 are critical (3%)
    public var fumbleAtLeast: Int = 97  // 97..99 are fumbles (3%)
    public init(criticalUnder: Int = 2, fumbleAtLeast: Int = 97) {
        self.criticalUnder = max(0, criticalUnder)
        self.fumbleAtLeast = min(99, fumbleAtLeast)
    }
}

public enum SkillSystem {
    /// Resolve one skill vs a DC in 0..100 (50 ≈ neutral; >50 harder, <50 easier).
    public static func check(
        id: SkillID,
        sheet: SkillSheet,
        catalog: SkillCatalog? = nil,
        dc: Int,
        rng: inout any Randomizer,
        config: SkillCheckConfig = .init()
    ) -> SkillOutcome {
        let total = sheet.total(of: id, using: catalog) // can exceed 100 with bonuses
        let roll = Int(rng.uniform(100)) // 0..99

        if roll <= config.criticalUnder { return .critical(roll: roll) }
        if roll >= config.fumbleAtLeast { return .fumble(roll: roll) }

        // Map DC into an effective target: higher DC makes it harder.
        // We treat DC 50 as "roll under total".
        let target = max(0, min(100, total - (dc - 50)))
        if roll <= target {
            return .success(roll: roll, margin: target - roll)
        } else {
            return .fail(roll: roll, margin: roll - target)
        }
    }

    /// Opposed test: attacker skill vs defender skill. Highest "score" wins.
    /// Score = total - roll (bounded). Critical beats non-critical, fumble loses to non-fumble.
    public static func opposed(
        attacker: (id: SkillID, sheet: SkillSheet),
        defender: (id: SkillID, sheet: SkillSheet),
        catalog: SkillCatalog? = nil,
        rng: inout any Randomizer,
        config: SkillCheckConfig = .init()
    ) -> (attacker: SkillOutcome, defender: SkillOutcome, attackerWins: Bool) {
        func score(_ outcome: SkillOutcome) -> (priority: Int, value: Int) {
            switch outcome {
            case .critical(let r): return (3, 100 - r)
            case .success(_, let m): return (2, m)
            case .fail(_, let m): return (1, -m)
            case .fumble(let r): return (0, -(100 - r))
            }
        }
        var r1 = rng, r2 = rng // copy for determinism with one stream if desired
        let a = check(id: attacker.id, sheet: attacker.sheet, catalog: catalog, dc: 50, rng: &r1, config: config)
        let d = check(id: defender.id, sheet: defender.sheet, catalog: catalog, dc: 50, rng: &r2, config: config)
        let sa = score(a), sd = score(d)
        let win = (sa.priority, sa.value) > (sd.priority, sd.value)
        return (a, d, win)
    }
}

// MARK: - A tiny built-in catalog you can extend in your seeding code

public enum BuiltInSkills {
    public static let sword        = SkillID("sword")
    public static let axe          = SkillID("axe")
    public static let polearm      = SkillID("polearm")
    public static let archery      = SkillID("archery")
    public static let fireMagic    = SkillID("fire_magic")
    public static let waterMagic   = SkillID("water_magic")
    public static let lockpicking  = SkillID("lockpicking")
    public static let stealth      = SkillID("stealth")
    public static let cartography  = SkillID("cartography")
    public static let diplomacy    = SkillID("diplomacy")
    public static let alchemy      = SkillID("alchemy")
    public static let athletics    = SkillID("athletics")
    public static let perception   = SkillID("perception")
    public static let disarm       = SkillID("disarm")

    public static func demoCatalog() -> SkillCatalog {
        var c = SkillCatalog()
        let mk: (SkillID, String, SkillDomain, Int, String?) -> AnySkillDef = { id, name, dom, maxR, desc in
            AnySkillDef(SkillDef<Never>(id: id, name: name, domain: dom, governingStat: nil, maxRanks: maxR, description: desc))
        }
        c.register(mk(sword,       "Sword",        .combat,   100, "Finesse with blades"))
        c.register(mk(axe,         "Axe",          .combat,   100, nil))
        c.register(mk(polearm,     "Polearm",      .combat,   100, nil))
        c.register(mk(archery,     "Archery",      .combat,   100, nil))
        c.register(mk(fireMagic,   "Fire Magic",   .magic,    100, "Pyromancy arts"))
        c.register(mk(waterMagic,  "Water Magic",  .magic,    100, nil))
        c.register(mk(lockpicking, "Lockpicking",  .stealth,  100, nil))
        c.register(mk(stealth,     "Stealth",      .stealth,  100, nil))
        c.register(mk(perception,  "Perception",   .lore,     100, "Spot secrets and traps"))
        c.register(mk(cartography, "Cartography",  .lore,     100, nil))
        c.register(mk(diplomacy,   "Diplomacy",    .social,   100, nil))
        c.register(mk(alchemy,     "Alchemy",      .crafting, 100, nil))
        c.register(mk(athletics,   "Athletics",    .survival, 100, nil))
        c.register(mk(disarm,      "Disarm",       .stealth,  100, "Disable traps and devices"))
        return c
    }
}

// MARK: - Resolver interface for systems outside GameCore to plug in

public protocol SkillResolver: Sendable {
    /// Perform a skill check (e.g., lockpicking) at a given DC with the provided RNG.
    func check(id: SkillID, dc: Int, rng: inout any Randomizer) -> SkillOutcome
}
