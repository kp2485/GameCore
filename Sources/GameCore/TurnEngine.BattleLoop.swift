//
//  TurnEngine.BattleLoop.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

public extension TurnEngine where A == Character {

    private func defeatedXP(_ enc: Encounter<Character>) -> Int {
        enc.foes.reduce(0) { $0 + (($1.hp <= 0) ? $1.xpValue : 0) }
    }

    /// Grants XP to allies based on defeated foes, appends events, and writes back encounter state.
    /// Returns appended events and possibly updated encounter.
    private func awardXPIfAlliesWin(
        enc: inout Encounter<Character>,
        seed: UInt64,
        tick: UInt64,
        into events: inout [Event]
    ) {
        let total = defeatedXP(enc)
        guard total > 0 else { return }

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
        let xpEvents = rt.grantXPToAllies(totalXP: total)
        events.append(contentsOf: xpEvents)
        enc = rt.encounter
    }

    /// Run combat until victory/defeat/stalemate. Deterministic given `seed`.
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
                awardXPIfAlliesWin(enc: &enc, seed: roundSeed, tick: 0, into: &allEvents)
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
                    awardXPIfAlliesWin(enc: &enc, seed: roundSeed, tick: tick, into: &allEvents)
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
