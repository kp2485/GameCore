//
//  StatusAdvancedTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct StatusAdvancedTests {

    private func C(_ name: String, hp: Int = 20, mp: Int = 0, extra: [CoreStat:Int] = [:]) -> Character {
        var stats: StatBlock<CoreStat> = StatBlock<CoreStat>([.hp: hp, .mp: mp, .vit: 6])
        for (k,v) in extra { stats[k] = v }
        return Character(name: name, stats: stats)
    }

    @Test
    func paralyzeSkipsTurn() {
        let ally = C("Paralyzed", hp: 18)
        let foe  = C("Gob", hp: 18)

        let enc = Encounter(allies: [Combatant(base: ally, hp: ally.stats[.hp])],
                            foes:   [Combatant(base: foe,  hp: foe.stats[.hp])])

        // Prepare initial statuses by using a runtime, then pass the map into the engine.
        var seedRT = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )
        seedRT.apply(status: Status(.paralyze, duration: 1, stacks: 1, rule: .stack(1)), to: ally)

        let engine = TurnEngine<Character>()
        let (ev, _) = engine.runOneRound(
            encounter: enc,
            seed: 5,
            initialStatuses: seedRT.statuses
        )

        let skipped = ev.contains { e in
            if case .note = e.kind, e.data["skip"] == "paralyzed" { return true }
            return false
        }
        #expect(skipped)
    }

    @Test
    func poisonDealsDamageAtEndOfTurn() {
        let ally = C("Hero", hp: 30)
        let foe  = C("Gob", hp: 20)

        let enc = Encounter(allies: [Combatant(base: ally, hp: ally.stats[.hp])],
                            foes:   [Combatant(base: foe,  hp: foe.stats[.hp])])

        // Seed poison on the goblin via statuses map and pass it in.
        var seedRT = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 9), statuses: [:], mp: [:], equipment: [:]
        )
        seedRT.apply(status: Status(.poison, duration: 2, stacks: 2, rule: .stack(10)), to: foe)

        let engine = TurnEngine<Character>()
        let (ev, res) = engine.runOneRound(
            encounter: enc,
            seed: 9,
            initialStatuses: seedRT.statuses
        )

        let poisonHit = ev.first(where: { e in
            if case .damage = e.kind, e.data["source"] == "poison", e.data["target"] == foe.name { return true }
            return false
        })
        #expect(poisonHit != nil)

        let gobHPAfter = (res.foes.first { $0.base.id == foe.id })?.hp ?? 0
        #expect(gobHPAfter < 20)
    }
}
