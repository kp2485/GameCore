//
//  TurnEngine.BattleLoop.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

public extension TurnEngine where A == Character {
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
            if enc.foesDefeated { return (allEvents, enc, .alliesWin) }
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
                    equipment: [:]
                )

                allEvents.append(Event(kind: .turnStart, timestamp: tick, data: ["actor": actor.name]))
                
                // Skip if paralyzed
                if rt.isParalyzed(actor) {
                    allEvents.append(Event(kind: .note, timestamp: tick, data: [
                        "skip": "paralyzed", "actor": actor.name
                    ]))
                    // End-of-turn poison and status ticking
                    allEvents.append(contentsOf: rt.applyPoisonTick(on: actor))
                    allEvents.append(contentsOf: rt.tickStatuses())
                    enc = rt.encounter
                    tick &+= 1
                    if enc.foesDefeated { return (allEvents, enc, .alliesWin) }
                    if enc.alliesDefeated { return (allEvents, enc, .foesWin) }
                    continue
                }

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

                // Tick statuses at end of the actor’s turn
                allEvents.append(contentsOf: rt.applyPoisonTick(on: actor))
                allEvents.append(contentsOf: rt.tickStatuses())

                // Write back encounter changes
                enc = rt.encounter
                tick &+= 1

                // Check victory mid-round if you want immediate resolution
                if enc.foesDefeated { return (allEvents, enc, .alliesWin) }
                if enc.alliesDefeated { return (allEvents, enc, .foesWin) }
            }

            // New seed each round for fresh—but deterministic—initiative variation
            roundSeed &+= 1
        }

        return (allEvents, enc, .stalemate)
    }
}
