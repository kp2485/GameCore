//
//  TargetingTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

private func C(_ name: String, _ stats: [CoreStat:Int]) -> Character {
    Character(name: name, stats: StatBlock(stats))
}

@Suite struct TargetingTests {

    @Test func resolverPicksExpectedTargets() {
        let hero = C("Hero", [.hp: 30, .str: 8, .spd: 8])
        let ally = C("Ally", [.hp: 25])
        let g1   = C("Gob A", [.hp: 18])
        let g2   = C("Gob B", [.hp: 18])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: hero.stats[.hp]),
                     Combatant(base: ally, hp: ally.stats[.hp])],
            foes:   [Combatant(base: g1,   hp: g1.stats[.hp]),
                     Combatant(base: g2,   hp: g2.stats[.hp])]
        )

        let rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )
        var rng: any Randomizer = SeededPRNG(seed: 5)
        let r = TargetResolver<Character>()

        #expect(r.resolve(mode: .selfOnly,   state: rt, rng: &rng) == [hero])
        #expect(r.resolve(mode: .firstFoe,   state: rt, rng: &rng).first == g1)
        #expect(r.resolve(mode: .allFoes,    state: rt, rng: &rng).count == 2)
        #expect(r.resolve(mode: .firstAlly,  state: rt, rng: &rng).first == ally)
        #expect(r.resolve(mode: .allAllies,  state: rt, rng: &rng).count == 2)

        // randomFoe is deterministic with seeded PRNG
        var rng2: any Randomizer = SeededPRNG(seed: 5)
        #expect(r.resolve(mode: .randomFoe, state: rt, rng: &rng2).count == 1)
    }

    @Test func targetedAttack_allFoes_hitsBoth() {
        let hero = C("Hero", [.hp: 30, .str: 9, .spd: 8])
        let g1   = C("Gob A", [.hp: 18, .spd: 4])
        let g2   = C("Gob B", [.hp: 18, .spd: 4])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: g1,   hp: 18),
                     Combatant(base: g2,   hp: 18)]
        )
        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )

        var rng: any Randomizer = SeededPRNG(seed: 9)
        var atk = TargetedAttack<Character>(mode: .allFoes, base: 5, varianceMax: 0)

        let before = rt.encounter.foes.map { $0.hp }
        _ = atk.perform(in: &rt, rng: &rng)
        let after  = rt.encounter.foes.map { $0.hp }

        #expect(after[0] < before[0])
        #expect(after[1] < before[1])
    }

    @Test func castWithTargeting_allFoes_spendsMPOnce() {
        let mage = C("Mage", [.hp: 24, .mp: 18, .int: 16])
        let g1   = C("Gob A", [.hp: 18])
        let g2   = C("Gob B", [.hp: 18])

        let enc = Encounter(
            allies: [Combatant(base: mage, hp: mage.stats[.hp])],
            foes:   [Combatant(base: g1,   hp: g1.stats[.hp]),
                     Combatant(base: g2,   hp: g2.stats[.hp])]
        )
        var rt = CombatRuntime<Character>(
            tick: 0, encounter: enc, currentIndex: 0, side: .allies,
            rngForInitiative: SeededPRNG(seed: 1), statuses: [:], mp: [:], equipment: [:]
        )
        rt.setMP(of: mage, to: mage.stats[.mp])

        var rng: any Randomizer = SeededPRNG(seed: 7)
        var cast = CastWithTargeting<Character, FireBlast<Character>>(mode: .allFoes)

        let mpBefore = rt.mp(of: mage)
        _ = cast.perform(in: &rt, rng: &rng)
        #expect(rt.mp(of: mage) == mpBefore - FireBlast<Character>.mpCost(for: mage))
    }
}
