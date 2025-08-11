//
//  Progression.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

// MARK: - Progression Model

public protocol ProgressionModel: Sendable {
    /// XP required to reach `level` from `level-1` (delta per level).
    func xpFor(level: Int) -> Int
    /// Stat/skill rewards applied when reaching `newLevel`.
    func rewards(for newLevel: Int) -> LevelRewards
}

/// Simple quadratic-ish curve: 100, 200, 300, ...
public struct DefaultProgression: ProgressionModel, Sendable {
    public init() {}
    public func xpFor(level: Int) -> Int { max(1, level) * 100 }
    public func rewards(for newLevel: Int) -> LevelRewards {
        LevelRewards(hpBonus: 8, mpBonus: 3, skillPoints: 3)
    }
}

public struct LevelRewards: Sendable, Equatable {
    public let hpBonus: Int
    public let mpBonus: Int
    public let skillPoints: Int
    public init(hpBonus: Int, mpBonus: Int, skillPoints: Int) {
        self.hpBonus = hpBonus
        self.mpBonus = mpBonus
        self.skillPoints = skillPoints
    }
}

// MARK: - Per-actor Level State

public struct LevelState: Sendable, Equatable {
    public var level: Int
    public var xp: Int                    // accumulated toward next level
    public var unspentSkillPoints: Int

    public init(level: Int = 1, xp: Int = 0, unspentSkillPoints: Int = 0) {
        precondition(level >= 1)
        self.level = level
        self.xp = max(0, xp)
        self.unspentSkillPoints = max(0, unspentSkillPoints)
    }
}

// MARK: - Runtime ops

public extension CombatRuntime where A == Character {

    /// Grant XP to all **living** allies; returns emitted events.
    mutating func grantXPToAllies(
        totalXP: Int,
        model: some ProgressionModel = DefaultProgression()
    ) -> [Event] {
        guard totalXP > 0 else { return [] }
        let living = encounter.allies.filter { $0.hp > 0 }
        guard !living.isEmpty else { return [] }

        let share = max(1, totalXP / living.count)
        var out: [Event] = []
        for c in living {
            out += grantXP(to: c.base, amount: share, model: model)
        }
        return out
    }

    /// Grant XP to a single character and process level-ups.
    @discardableResult
    mutating func grantXP(
        to actor: Character,
        amount: Int,
        model: some ProgressionModel = DefaultProgression()
    ) -> [Event] {
        guard amount > 0 else { return [] }
        var out: [Event] = []

        var st = levels[actor.id] ?? LevelState()
        st.xp &+= amount

        out.append(Event(kind: .xpGained, timestamp: tick, data: [
            "actor": actor.name, "amount": String(amount), "level": String(st.level)
        ]))

        // Level-up loop (handles multiple levels if XP is large)
        while st.xp >= model.xpFor(level: st.level + 1) {
            st.xp -= model.xpFor(level: st.level + 1)
            st.level &+= 1
            let rewards = model.rewards(for: st.level)

            // Apply HP/MP growth via current encounter state
            if var hp = self.hp(of: actor) {
                hp &+= rewards.hpBonus
                setHP(of: actor, to: hp)
            }
            let curMP = mp(of: actor)
            setMP(of: actor, to: curMP + rewards.mpBonus)

            st.unspentSkillPoints &+= rewards.skillPoints

            out.append(Event(kind: .levelUp, timestamp: tick, data: [
                "actor": actor.name,
                "newLevel": String(st.level),
                "hpBonus": String(rewards.hpBonus),
                "mpBonus": String(rewards.mpBonus),
                "skillPoints": String(rewards.skillPoints)
            ]))
        }

        levels[actor.id] = st
        return out
    }
}
