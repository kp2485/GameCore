//
//  TurnEngine.BattleLoop.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

public extension TurnEngine where A == Character {

    // MARK: - Reward helpers

    private func defeatedXP(_ enc: Encounter<Character>) -> Int {
        enc.foes.reduce(0) { $0 + (($1.hp <= 0) ? $1.xpValue : 0) }
    }

    private func defeatedGold(_ enc: Encounter<Character>) -> Int {
        enc.foes.reduce(0) { $0 + (($1.hp <= 0) ? $1.goldValue : 0) }
    }

    /// Roll and aggregate loot from all defeated foes using a deterministic RNG.
    private func defeatedLoot(_ enc: Encounter<Character>, rng: inout any Randomizer) -> [(id: String, qty: Int)] {
        var all: [String: Int] = [:]
        for f in enc.foes where f.hp <= 0 {
            if let bundle = f.loot {
                for (id, q) in bundle.roll(rng: &rng) {
                    all[id, default: 0] += q
                }
            }
        }
        return all.map { ($0.key, $0.value) }
    }

    /// Grants XP, gold, and loot on allies' victory; appends events; writes back encounter.
    private func awardVictoryRewards(
        enc: inout Encounter<Character>,
        seed: UInt64,
        tick: UInt64,
        into events: inout [Event]
    ) {
        // 1) XP
        let totalXP = defeatedXP(enc)
        if totalXP > 0 {
            var rt = CombatRuntime<Character>(
                tick: tick,
                encounter: enc,
                currentIndex: 0,
                side: .allies,
                rngForInitiative: SeededPRNG(seed: seed),
                statuses: [:],
                mp: [:],
                equipment: [:],
                levels: [:]
            )
            let xpEvents = rt.grantXPToAllies(totalXP: totalXP)
            events.append(contentsOf: xpEvents)
            enc = rt.encounter
        }

        // 2) Gold
        let gold = defeatedGold(enc)
        if gold > 0 {
            events.append(Event(kind: .goldAwarded, timestamp: tick, data: ["amount": String(gold)]))
        }

        // 3) Loot (deterministic roll from a separate stream)
        var lootRNG: any Randomizer = SeededPRNG(seed: seed &+ 777)
        let drops = defeatedLoot(enc, rng: &lootRNG)
        for d in drops where d.qty > 0 {
            events.append(Event(kind: .lootDropped, timestamp: tick, data: [
                "itemId": d.id, "qty": String(d.qty)
            ]))
        }
    }

    // MARK: - Battle loop

    /// Run combat until victory/defeat/stalemate. Deterministic given `seed`.
    /// - Parameters:
    ///   - encounter: starting state
    ///   - allyControllers: one per ally (same order as `encounter.allies`)
    ///   - foeControllers: one per foe   (same order as `encounter.foes`)
    ///   - seed: base seed for initiative and actions
    ///   - maxRounds: safety cap
    /// - Returns: all emitted events and the final encounter + outcome
    func runUntilVictory(
        encounter: Encounter<Character>,
        allyControllers: [any Controller<Character>],
        foeControllers: [any Controller<Character>],
        seed: UInt64,
        maxRounds: Int = 50
    ) -> (events: [Event], result: Encounter<Character>, outcome: BattleOutcome) {

        var enc = encounter
        var allEvents: [Event] = []
        var roundSeed = seed
        var actionRNG: any Randomizer = SeededPRNG(seed: seed &+ 10)

        for _ in 0..<maxRounds {
            // Victory check at start of round
            if enc.foesDefeated {
                awardVictoryRewards(enc: &enc, seed: roundSeed, tick: 0, into: &allEvents)
                return (allEvents, enc, .alliesWin)
            }
            if enc.alliesDefeated { return (allEvents, enc, .foesWin) }

            // Determine order for this round
            let order = initiativeOrder(for: enc, seed: roundSeed)
            var tick: UInt64 = 0

            for (side, index, actor, _) in order {
                // Skip dead
                switch side {
                case .allies:
                    if enc.allies[index].hp <= 0 { continue }
                case .foes:
                    if enc.foes[index].hp <= 0 { continue }
                }

                var rt = CombatRuntime<Character>(
                    tick: tick,
                    encounter: enc,
                    currentIndex: index,
                    side: side,
                    rngForInitiative: SeededPRNG(seed: roundSeed),
                    statuses: [:],
                    mp: [:],
                    equipment: [:],
                    levels: [:]
                )

                allEvents.append(Event(kind: .turnStart, timestamp: tick, data: ["actor": actor.name]))

                // Pick controller by side/index
                let plan: ActionPlan<Character>?
                switch side {
                case .allies:
                    plan = index < allyControllers.count ? allyControllers[index].plan(in: rt, rng: &actionRNG) : nil
                case .foes:
                    plan = index < foeControllers.count ? foeControllers[index].plan(in: rt, rng: &actionRNG) : nil
                }

                if let plan {
                    let ev = plan.exec(&rt, &actionRNG)
                    allEvents.append(contentsOf: ev)
                }

                // Tick statuses at end of the actor’s turn (optional)
                allEvents.append(contentsOf: rt.tickStatuses())

                // Write back encounter changes
                enc = rt.encounter
                tick &+= 1

                // Mid-round immediate victory check
                if enc.foesDefeated {
                    awardVictoryRewards(enc: &enc, seed: roundSeed, tick: tick, into: &allEvents)
                    return (allEvents, enc, .alliesWin)
                }
                if enc.alliesDefeated { return (allEvents, enc, .foesWin) }
            }

            // New seed each round for fresh—but deterministic—initiative variation
            roundSeed &+= 1
        }

        return (allEvents, enc, .stalemate)
    }
}
