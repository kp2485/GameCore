//
//  Movement.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation
import GameCore // for Randomizer, SkillResolver, SkillID, BuiltInSkills
/// A callback invoked when a trap deals environmental damage.
/// Pass the raw damage amount; the app decides how to distribute it (all members, front row only, etc.).
public typealias TrapDamageHandler = @Sendable (_ damage: Int) -> Void

public struct MovementResult: Sendable, Equatable {
    public let moved: Bool
    public let position: GridCoord
    public let facing: Direction
    public let triggeredEncounterId: String?
    public let trapDamage: Int?
    public init(
        moved: Bool,
        position: GridCoord,
        facing: Direction,
        triggeredEncounterId: String?,
        trapDamage: Int? = nil
    ) {
        self.moved = moved
        self.position = position
        self.facing = facing
        self.triggeredEncounterId = triggeredEncounterId
        self.trapDamage = trapDamage
    }
}

/// Optional per-step modifiers affecting exploration behavior.
public struct StepModifiers: Sendable, Equatable {
    /// Percent chance to **suppress** a random encounter on a step (e.g., “repel”).
    /// 0 = off, 100 = always suppress.
    public var repelEncounterPercent: Int = 0
    public init(repelEncounterPercent: Int = 0) {
        self.repelEncounterPercent = min(max(0, repelEncounterPercent), 100)
    }
}

/// Minimal runtime for exploring a GameMap, with fog-of-war and interaction.
public struct MapRuntime: Sendable, Equatable {
    public var map: GameMap                      // mutable to reveal/open/toggle/etc.
    public private(set) var position: GridCoord
    public private(set) var facing: Direction
    public private(set) var steps: Int
    public private(set) var fog: Set<GridCoord>
    public var modifiers: StepModifiers
    
    public init(map: GameMap,
                start: GridCoord,
                facing: Direction = .north,
                steps: Int = 0,
                fog: Set<GridCoord> = [],
                modifiers: StepModifiers = .init()) {
        precondition(map.inBounds(start), "Start must be within map bounds")
        self.map = map
        self.position = start
        self.facing = facing
        self.steps = max(0, steps)
        self.fog = fog
        self.modifiers = modifiers
    }
    
    public func regionName(at p: GridCoord) -> String? {
        for (name, region) in map.regions where region.contains(p) { return name }
        return nil
    }
    
    @discardableResult
    public mutating func turnLeft() -> MovementResult {
        facing = facing.turnLeft()
        return MovementResult(moved: false, position: position, facing: facing, triggeredEncounterId: nil)
    }
    
    @discardableResult
    public mutating func turnRight() -> MovementResult {
        facing = facing.turnRight()
        return MovementResult(moved: false, position: position, facing: facing, triggeredEncounterId: nil)
    }
    
    /// Attempt to move forward one tile (legacy, no skills). Calls the resolver-aware variant.
    @discardableResult
    public mutating func moveForward(rng: inout any Randomizer) -> MovementResult {
        return moveForward(resolver: nil, rng: &rng, trapDamageHandler: nil)
    }
    
    /// Attempt to move forward one tile (skill-aware). Triggers traps on entry.
    /// If a trap fires, `trapDamageHandler` (if provided) is called with the damage value.
    @discardableResult
    public mutating func moveForward(
        resolver: (any SkillResolver)?,
        rng: inout any Randomizer,
        trapDamageHandler: TrapDamageHandler? = nil
    ) -> MovementResult {
        guard let next = map.neighbor(of: position, toward: facing) else {
            return MovementResult(moved: false, position: position, facing: facing, triggeredEncounterId: nil)
        }
        guard Navigation.canMove(from: position, toward: facing, on: map) else {
            return MovementResult(moved: false, position: position, facing: facing, triggeredEncounterId: nil)
        }
        
        position = next
        steps &+= 1
        
        var trapDamage: Int? = nil
        
        // Movement-triggered traps: after entering destination tile
        switch map[position].feature {
        case .trap(id: let tid, detectDC: let det, disarmDC: let dis, damage: let dmg, once: let once, armed: let armed)
            where armed:
            trapDamage = dmg
            trapDamageHandler?(dmg)  // ← notify app/party layer
            map[position].feature = once
            ? .none
            : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
        default:
            break
        }
        
        // Repel checks
        if modifiers.repelEncounterPercent > 0 {
            let roll = Int(rng.uniform(100))
            if roll < modifiers.repelEncounterPercent {
                return MovementResult(moved: true, position: position, facing: facing, triggeredEncounterId: nil, trapDamage: trapDamage)
            }
        }
        
        let encounterId = encounterRollIfAny(rng: &rng)
        return MovementResult(moved: true, position: position, facing: facing, triggeredEncounterId: encounterId, trapDamage: trapDamage)
    }
    
    /// Reveal fog-of-war by unioning tiles visible within `radius` from current position.
    @discardableResult
    public mutating func revealFOV(radius: Int) -> Set<GridCoord> {
        let seen = LOS.visible(from: position, radius: radius, on: map)
        fog.formUnion(seen)
        return seen
    }
    
    // MARK: - Interaction
    
    public enum InteractionOutcome: Sendable, Equatable {
        case nothing
        case doorOpened
        case doorLocked
        case secretRevealed
        case secretNotFound
        case leverToggled(newState: Bool)
        case foundNote(String)
        case blockedByWall
        case lockpickSuccess
        case lockpickFailed(margin: Int)
        case trapDetected
        case trapDisarmed
        case trapTriggered(damage: Int)
    }
    
    /// Legacy convenience: interacts without skills (keeps prior behavior).
    @discardableResult
    public mutating func interactAhead() -> InteractionOutcome {
        // Old behavior: reveal secret edges/doors instantly (no skill gate).
        guard let ahead = map.neighbor(of: position, toward: facing) else { return .blockedByWall }
        
        var cur = map[position]
        if cur.walls.contains(.secret) {
            cur.walls.remove(.secret)
            map[position] = cur
            return .secretRevealed
        }
        switch map[ahead].feature {
        case .door(locked: let locked, secret: let secret, lockDC: let dc, lockSkill: let skill) where secret:
            map[ahead].feature = .door(locked: locked, secret: false, lockDC: dc, lockSkill: skill)
            return .secretRevealed
        default:
            break
        }
        
        // Defer to the skill-aware path with a dummy resolver = nil (doors remain locked, etc.)
        var dummy: any Randomizer = SeededPRNG(seed: 0)
        return interactAhead(resolver: nil, rng: &dummy)
    }
    
    /// Skill-aware interaction. Uses Perception for secrets and per-door lock DC/skill for locks.
    @discardableResult
    public mutating func interactAhead(
        resolver: (any SkillResolver)?,
        rng: inout any Randomizer,
        trapDamageHandler: TrapDamageHandler? = nil
    ) -> InteractionOutcome {
        guard let ahead = map.neighbor(of: position, toward: facing) else { return .blockedByWall }
        
        // 1) Secret edge between current and ahead: if resolver available, require Perception(DC 60)
        var cur = map[position]
        if cur.walls.contains(.secret) {
            if let resolver {
                let outcome = resolver.check(id: BuiltInSkills.perception, dc: 60, rng: &rng)
                switch outcome {
                case .critical, .success:
                    cur.walls.remove(.secret)
                    map[position] = cur
                    return .secretRevealed
                default:
                    return .secretNotFound
                }
            } else {
                // No resolver → legacy reveal
                cur.walls.remove(.secret)
                map[position] = cur
                return .secretRevealed
            }
        }
        
        // 2) Prefer AHEAD tile interactions first
        switch map[ahead].feature {
        case .door(locked: let locked, secret: let secret, lockDC: let dc, lockSkill: let skill) where secret:
            if let resolver {
                let outcome = resolver.check(id: BuiltInSkills.perception, dc: 60, rng: &rng)
                switch outcome {
                case .critical, .success:
                    map[ahead].feature = .door(locked: locked, secret: false, lockDC: dc, lockSkill: skill)
                    return .secretRevealed
                default:
                    return .secretNotFound
                }
            } else {
                map[ahead].feature = .door(locked: locked, secret: false, lockDC: dc, lockSkill: skill)
                return .secretRevealed
            }
            
        case .door(locked: let locked, secret: _, lockDC: let dc, lockSkill: let skill):
            if locked {
                if let resolver {
                    let effectiveDC = dc ?? 60
                    let skillName = skill ?? "lockpicking"
                    let outcome = resolver.check(id: SkillID(skillName), dc: effectiveDC, rng: &rng)
                    switch outcome {
                    case .critical, .success:
                        map[ahead].feature = .none
                        return .lockpickSuccess
                    case .fail(_, let margin):
                        return .lockpickFailed(margin: margin)
                    case .fumble:
                        return .lockpickFailed(margin: 999)
                    }
                }
                return .doorLocked
            } else {
                map[ahead].feature = .none
                return .doorOpened
            }
            
        case .lever(id: let id, isOn: let isOn):
            map[ahead].feature = .lever(id: id, isOn: !isOn)
            return .leverToggled(newState: !isOn)
            
        case .note(text: let text):
            return .foundNote(text)
            
        case .trap(id: let tid, detectDC: let det, disarmDC: let dis, damage: let dmg, once: let once, armed: let armed):
            guard armed else { break }
            if let resolver {
                // First: detection gate
                let spot = resolver.check(id: BuiltInSkills.perception, dc: det, rng: &rng)
                switch spot {
                case .critical, .success:
                    // Then: try to disarm
                    let disRes = resolver.check(id: BuiltInSkills.disarm, dc: dis, rng: &rng)
                    switch disRes {
                    case .critical, .success:
                        map[ahead].feature = once ? .none : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
                        return .trapDisarmed
                    default:
                        // Failed disarm → trigger
                        map[ahead].feature = once ? .none : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
                        trapDamageHandler?(dmg)
                        return .trapTriggered(damage: dmg)
                    }
                default:
                    // NEW: failed to detect → fumble the interaction and trigger
                    map[ahead].feature = once ? .none : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
                    trapDamageHandler?(dmg)
                    return .trapTriggered(damage: dmg)
                }
            } else {
                // No skills available: trigger immediately on interact
                map[ahead].feature = once ? .none : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
                trapDamageHandler?(dmg)
                return .trapTriggered(damage: dmg)
            }
            
        default:
            break
        }
        
        // 3) Fallback: CURRENT tile interactions
        switch map[position].feature {
        case .door(locked: let locked, secret: let secret, lockDC: let dc, lockSkill: let skill) where secret:
            if let resolver {
                let outcome = resolver.check(id: BuiltInSkills.perception, dc: 60, rng: &rng)
                switch outcome {
                case .critical, .success:
                    map[position].feature = .door(locked: locked, secret: false, lockDC: dc, lockSkill: skill)
                    return .secretRevealed
                default:
                    return .secretNotFound
                }
            } else {
                map[position].feature = .door(locked: locked, secret: false, lockDC: dc, lockSkill: skill)
                return .secretRevealed
            }
            
        case .door(locked: let locked, secret: _, lockDC: let dc, lockSkill: let skill):
            if locked {
                if let resolver {
                    let effectiveDC = dc ?? 60
                    let skillName = skill ?? "lockpicking"
                    let outcome = resolver.check(id: SkillID(skillName), dc: effectiveDC, rng: &rng)
                    switch outcome {
                    case .critical, .success:
                        map[position].feature = .none
                        return .lockpickSuccess
                    case .fail(_, let margin):
                        return .lockpickFailed(margin: margin)
                    case .fumble:
                        return .lockpickFailed(margin: 999)
                    }
                }
                return .doorLocked
            } else {
                map[position].feature = .none
                return .doorOpened
            }
            
        case .lever(id: let id, isOn: let isOn):
            map[position].feature = .lever(id: id, isOn: !isOn)
            return .leverToggled(newState: !isOn)
            
        case .note(text: let text):
            return .foundNote(text)
            
        case .trap(id: let tid, detectDC: let det, disarmDC: let dis, damage: let dmg, once: let once, armed: let armed):
            guard armed else { break }
            if let resolver {
                let spot = resolver.check(id: BuiltInSkills.perception, dc: det, rng: &rng)
                switch spot {
                case .critical, .success:
                    let disRes = resolver.check(id: BuiltInSkills.disarm, dc: dis, rng: &rng)
                    switch disRes {
                    case .critical, .success:
                        map[position].feature = once ? .none : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
                        return .trapDisarmed
                    default:
                        map[position].feature = once ? .none : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
                        trapDamageHandler?(dmg)
                        return .trapTriggered(damage: dmg)
                    }
                default:
                    // NEW: failed to detect → trigger
                    map[position].feature = once ? .none : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
                    trapDamageHandler?(dmg)
                    return .trapTriggered(damage: dmg)
                }
            } else {
                map[position].feature = once ? .none : .trap(id: tid, detectDC: det, disarmDC: dis, damage: dmg, once: once, armed: false)
                trapDamageHandler?(dmg)
                return .trapTriggered(damage: dmg)
            }
            
        default:
            break
        }
        
        // 4) Still nothing interactable; if there’s a hard edge, report it
        if Navigation.edgeBlocked(from: position, toward: facing, on: map) {
            return .blockedByWall
        }
        return .nothing
    }
    
    // MARK: - Private
    
    private func encounterRollIfAny(rng: inout any Randomizer) -> String? {
        guard let region = regionName(at: position), let table = map.regions[region]?.encounter else { return nil }
        return table.roll(stepCount: steps, rng: &rng)
    }
}
