import Foundation

// MARK: - Helpers

fileprivate extension Array {
    subscript(safe index: Int) -> Element? {
        (index >= 0 && index < count) ? self[index] : nil
    }
}

// MARK: - Combat primitives

public struct Combatant<A: GameActor>: Identifiable, Sendable, Equatable {
    public var base: A
    public var hp: Int
    public var id: UUID { base.id }

    public init(base: A, hp: Int) {
        self.base = base
        self.hp = hp
    }
}

public struct Encounter<A: GameActor>: Sendable, Equatable {
    public var allies: [Combatant<A>]
    public var foes: [Combatant<A>]

    public init(allies: [Combatant<A>], foes: [Combatant<A>]) {
        self.allies = allies
        self.foes = foes
    }
}

// MARK: - Runtime state (embedded status + MP)

public struct CombatRuntime<A: GameActor>: Sendable {
    public var tick: UInt64
    public private(set) var encounter: Encounter<A>
    public let currentIndex: Int
    public let side: Side
    public var rngForInitiative: any Randomizer

    public enum Side: Sendable { case allies, foes }

    /// Per-combatant statuses keyed by Actor UUID
    public var statuses: [UUID: [Status.Id: Status]] = [:]

    /// Per-combatant MP keyed by Actor UUID
    public var mp: [UUID: Int] = [:]
    
    /// Per-combatant equipment keyed by Actor UUID (optional; tests can populate).
    public var equipment: [UUID: Equipment] = [:]
    
    /// Per-character leveling state keyed by Actor UUID.
    public var levels: [UUID: LevelState] = [:]

    /// Defensive access to the current actor. Traps with a clear message if
    /// currentIndex does not exist on the chosen side.
    public var currentActor: A {
        switch side {
        case .allies:
            if let c = encounter.allies[safe: currentIndex]?.base { return c }
            preconditionFailure(
                "Invalid currentIndex \(currentIndex) for allies (count \(encounter.allies.count)). " +
                "Make sure you construct CombatRuntime with a valid index for the selected side."
            )
        case .foes:
            if let c = encounter.foes[safe: currentIndex]?.base { return c }
            preconditionFailure(
                "Invalid currentIndex \(currentIndex) for foes (count \(encounter.foes.count)). " +
                "Make sure you construct CombatRuntime with a valid index for the selected side."
            )
        }
    }

    // MARK: HP helpers

    public func hp(of actor: A) -> Int? {
        if let idx = encounter.allies.firstIndex(where: { $0.base.id == actor.id }) { return encounter.allies[idx].hp }
        if let idx = encounter.foes.firstIndex(where: { $0.base.id == actor.id }) { return encounter.foes[idx].hp }
        return nil
    }

    public mutating func setHP(of actor: A, to newValue: Int) {
        if let idx = encounter.allies.firstIndex(where: { $0.base.id == actor.id }) { encounter.allies[idx].hp = newValue; return }
        if let idx = encounter.foes.firstIndex(where: { $0.base.id == actor.id }) { encounter.foes[idx].hp = newValue; return }
    }

    public func maxHP(of actor: A) -> Int {
        (actor as? Character)?.stats.maxHP ?? 1
    }

    // MARK: Sides & membership

    public func foes(of actor: A) -> [A] {
        if encounter.allies.contains(where: { $0.base.id == actor.id }) {
            return encounter.foes.filter { $0.hp > 0 }.map { $0.base }
        } else {
            return encounter.allies.filter { $0.hp > 0 }.map { $0.base }
        }
    }

    public func allies(of actor: A) -> [A] {
        if encounter.allies.contains(where: { $0.base.id == actor.id }) {
            return encounter.allies.filter { $0.hp > 0 }.map { $0.base }
        } else {
            return encounter.foes.filter { $0.hp > 0 }.map { $0.base }
        }
    }

    /// Replace an actor payload inside the encounter by ID (e.g., after stat changes)
    public mutating func overwriteActor(_ newActor: A) {
        if let idx = encounter.allies.firstIndex(where: { $0.base.id == newActor.id }) {
            encounter.allies[idx].base = newActor
        } else if let idx = encounter.foes.firstIndex(where: { $0.base.id == newActor.id }) {
            encounter.foes[idx].base = newActor
        }
    }

    // MARK: Status operations

    public mutating func apply(status: Status, to actor: A) {
        var map = statuses[actor.id] ?? [:]
        if let existing = map[status.id] {
            map[status.id] = existing.refreshed(applying: status)
        } else {
            map[status.id] = status
        }
        statuses[actor.id] = map
    }

    public func status(of id: Status.Id, on actor: A) -> Status? {
        statuses[actor.id]?[id]
    }

    /// Decrement duration; emit expiration events
    public mutating func tickStatuses() -> [Event] {
        var out: [Event] = []
        for (uid, sMap) in statuses {
            var newMap: [Status.Id: Status] = [:]
            for (sid, s) in sMap {
                if let nxt = s.ticked() {
                    newMap[sid] = nxt
                } else {
                    out.append(
                        Event(kind: .statusExpired, timestamp: tick, data: [
                            "status": sid.rawValue,
                            "target": "uid:\(uid)"
                        ])
                    )
                }
            }
            statuses[uid] = newMap
        }
        return out
    }

    // MARK: MP & costs

    public mutating func setMP(of actor: A, to value: Int) {
        mp[actor.id] = max(0, value)
    }

    public func mp(of actor: A) -> Int {
        // default to computed max if not initialized
        mp[actor.id] ?? defaultMaxMP(for: actor)
    }

    /// Spend MP if possible; returns true when successful.
    public mutating func spendMP(of actor: A, cost: Int) -> Bool {
        let cur = mp(of: actor)
        guard cur >= cost else { return false }
        setMP(of: actor, to: cur - cost)
        return true
    }

    /// Simple default max MP derived from Character stats (can be made data-driven later).
    public func defaultMaxMP(for actor: A) -> Int {
        (actor as? Character)?.stats.maxMP ?? 0
    }

    // MARK: Mitigation from statuses (shield/defend/etc.)

    public func mitigationPercent(for actor: A) -> Int {
        var pct = 0
        if let s = status(of: .shield, on: actor) {
            // Each stack grants 20% (cap 80%)
            pct = min(80, pct + 20 * s.stacks)
        }
        return min(100, max(0, pct))
    }
}

public extension CombatRuntime {
    /// True if actor currently has the 'paralyze' status.
    func isParalyzed(_ actor: A) -> Bool {
        status(of: .paralyze, on: actor) != nil
    }

    /// Apply poison damage (if any) to `actor`. Damage is 2 per stack.
    /// Emits a `.damage` event and optional `.death` if HP hits 0.
    @discardableResult
    mutating func applyPoisonTick(on actor: A) -> [Event] {
        guard let s = status(of: .poison, on: actor), s.stacks > 0 else { return [] }
        let perStack = 2
        let total = perStack * s.stacks

        var out: [Event] = []
        if var hp = hp(of: actor) {
            let before = hp
            hp = max(0, before - total)
            setHP(of: actor, to: hp)

            out.append(Event(kind: .damage, timestamp: tick, data: [
                "amount": String(total),
                "source": "poison",
                "target": actor.name,
                "hpBefore": String(before),
                "hpAfter": String(hp)
            ]))

            if hp == 0 {
                out.append(Event(kind: .death, timestamp: tick, data: [
                    "target": actor.name,
                    "by": "poison"
                ]))
            }
        }
        return out
    }
}

// MARK: - Initiative & engine

public struct InitiativeRoll<A: GameActor>: Sendable, Equatable {
    public let id: UUID
    public let speed: Int
    public let roll: Int
}

public struct TurnEngine<A: GameActor>: Sendable {
    public init() {}

    public func initiativeOrder(
        for enc: Encounter<A>,
        seed: UInt64
    ) -> [(side: CombatRuntime<A>.Side, index: Int, actor: A, total: Int)] {
        var rng: any Randomizer = SeededPRNG(seed: seed)
        var entries: [(CombatRuntime<A>.Side, Int, A, Int)] = []

        for (i, c) in enc.allies.enumerated() {
            let baseSpd = (c.base as? Character)?.stats[.spd] ?? 0
            let r = Int(rng.uniform(10))
            entries.append((.allies, i, c.base, baseSpd + r))
        }
        for (i, c) in enc.foes.enumerated() {
            let baseSpd = (c.base as? Character)?.stats[.spd] ?? 0
            let r = Int(rng.uniform(10))
            entries.append((.foes, i, c.base, baseSpd + r))
        }

        // Sort by total desc, then name desc as a stable tiebreaker
        return entries.sorted(by: { lhs, rhs in
            (lhs.3, lhs.2.name) > (rhs.3, rhs.2.name)
        })
    }

    /// Execute one round: each living combatant performs a basic Attack.
    public func runOneRound(
            encounter: Encounter<A>,
            seed: UInt64,
            initialStatuses: [UUID: [Status.Id: Status]] = [:],
            initialMP: [UUID: Int] = [:],
            initialEquipment: [UUID: Equipment] = [:]
        ) -> (events: [Event], result: Encounter<A>) {

            var enc = encounter
            var events: [Event] = []
            let order = initiativeOrder(for: enc, seed: seed)

            var tick: UInt64 = 0
            var rng: any Randomizer = SeededPRNG(seed: seed &+ 1)

            // Thread the maps through each actor’s turn so changes persist within the round.
            var statuses = initialStatuses
            var mp       = initialMP
            var equip    = initialEquipment

            for (side, index, actor, _) in order {
                // Skip if this combatant died earlier in the round
                switch side {
                case .allies: if enc.allies[safe: index]?.hp ?? 0 <= 0 { continue }
                case .foes:   if enc.foes[safe: index]?.hp   ?? 0 <= 0 { continue }
                }

                var runtime = CombatRuntime<A>(
                    tick: tick,
                    encounter: enc,
                    currentIndex: index,
                    side: side,
                    rngForInitiative: SeededPRNG(seed: seed),
                    statuses: statuses,
                    mp: mp,
                    equipment: equip
                )

                events.append(Event(kind: .turnStart, timestamp: tick, data: ["actor": actor.name]))

                // Skip if paralyzed
                if runtime.isParalyzed(actor) {
                    events.append(Event(kind: .note, timestamp: tick, data: [
                        "skip": "paralyzed", "actor": actor.name
                    ]))
                    // End-of-turn poison tick even if skipped
                    events.append(contentsOf: runtime.applyPoisonTick(on: actor))
                    // Decrement durations globally
                    events.append(contentsOf: runtime.tickStatuses())

                    // Write back state & continue
                    enc     = runtime.encounter
                    statuses = runtime.statuses
                    mp       = runtime.mp
                    equip    = runtime.equipment
                    tick &+= 1
                    continue
                }

                // Default action: Attack
                var action = Attack<A>(damage: Damage(kind: .physical, base: 5, scale: { (_: A) in 3 }))
                let actionEvents = action.perform(in: &runtime, rng: &rng)
                events.append(contentsOf: actionEvents)

                // End-of-turn effects
                events.append(contentsOf: runtime.applyPoisonTick(on: actor))
                events.append(contentsOf: runtime.tickStatuses())

                // Write back encounter state & maps for the next actor
                enc      = runtime.encounter
                statuses = runtime.statuses
                mp       = runtime.mp
                equip    = runtime.equipment
                tick &+= 1
            }

            return (events, enc)
        }
}
