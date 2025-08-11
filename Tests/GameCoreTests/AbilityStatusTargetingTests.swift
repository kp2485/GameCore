//
//  AbilityStatusTargetingTests.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation
import Testing
@testable import GameCore

private func char(_ name: String, _ stats: [CoreStat: Int]) -> Character {
    Character(name: name, stats: StatBlock(stats))
}

@Suite struct AbilityStatusTargetingTests {

    @Test
    func applyStatusStacksOrRefreshes() {
        let hero = char("Hero", [.spd: 5, .str: 6, .vit: 4])
        let gob  = char("Gob",  [.spd: 4, .vit: 2])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: gob,  hp: 18)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        var rng: any Randomizer = SeededPRNG(seed: 7)

        // Ability: Stagger (applies a 2-round staggered)
        let stagger = Ability<Character>(
            name: "Stagger",
            costMP: 0,
            targeting: .firstFoe,
            effects: [
                AnyEffect(ApplyStatus<Character>(Status(.staggered, duration: 2)))
            ]
        )

        var cast = Cast<Character>(stagger)
        let ev1 = cast.perform(in: &rt, rng: &rng)
        #expect(ev1.contains { $0.kind == Event.Kind.statusApplied })

        // Re-apply; with replace rule it should refresh to max(2,2)=2
        let ev2 = cast.perform(in: &rt, rng: &rng)
        #expect(ev2.contains { $0.kind == Event.Kind.statusApplied })

        let s = rt.status(of: .staggered, on: gob)!
        #expect(s.duration == 2)
        #expect(s.stacks == 1)
    }

    @Test
    func stackingStatusIncrementsStacks() {
        let hero = char("Hero", [.spd: 5])
        let gob  = char("Gob",  [.spd: 4])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: gob,  hp: 18)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        var rng: any Randomizer = SeededPRNG(seed: 9)

        let stacking = Status(.regen, duration: 3, stacks: 1, rule: .stack(3))
        let ability = Ability<Character>(
            name: "Regen",
            costMP: 0,
            targeting: .firstAlly,
            effects: [
                AnyEffect(ApplyStatus<Character>(stacking))
            ]
        )

        var cast = Cast<Character>(ability)
        _ = cast.perform(in: &rt, rng: &rng)
        _ = cast.perform(in: &rt, rng: &rng)

        let s = rt.status(of: .regen, on: hero)!
        #expect(s.stacks == 2)
        #expect(s.duration == 3)
    }

    @Test
    func statusTicksAndExpires() {
        let hero = char("Hero", [.spd: 5])
        let gob  = char("Gob",  [.spd: 4])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 30)],
            foes:   [Combatant(base: gob,  hp: 18)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )

        // apply a 1-turn status
        rt.apply(status: Status(.staggered, duration: 1), to: hero)
        let ev = rt.tickStatuses()
        #expect(ev.contains { $0.kind == Event.Kind.statusExpired })
        #expect(rt.status(of: .staggered, on: hero) == nil)
    }

    @Test
    func targetingResolvesCorrectSets() {
        let a = char("A", [.spd: 5])
        let b = char("B", [.spd: 4])
        let c = char("C", [.spd: 6])

        // c is dead
        let enc = Encounter(
            allies: [Combatant(base: a, hp: 10)],
            foes:   [Combatant(base: b, hp: 10), Combatant(base: c, hp: 0)]
        )

        let rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        var rng: any Randomizer = SeededPRNG(seed: 2)

        let resolver = TargetResolver<Character>()
        #expect(resolver.resolve(mode: .selfOnly,   state: rt, rng: &rng).map(\.name) == ["A"])
        #expect(resolver.resolve(mode: .firstFoe,   state: rt, rng: &rng).map(\.name) == ["B"])
        #expect(resolver.resolve(mode: .allFoes,    state: rt, rng: &rng).map(\.name) == ["B"])
        #expect(resolver.resolve(mode: .firstAlly,  state: rt, rng: &rng).map(\.name) == ["A"])
        #expect(resolver.resolve(mode: .allAllies,  state: rt, rng: &rng).map(\.name) == ["A"])
    }

    @Test
    func castAbilityRunsEffects() {
        let hero = char("Mage", [.int: 8, .spd: 6])
        let gob  = char("Gob",  [.vit: 2, .spd: 4])

        let enc = Encounter(
            allies: [Combatant(base: hero, hp: 20)],
            foes:   [Combatant(base: gob,  hp: 12)]
        )

        var rt = CombatRuntime<Character>(
            tick: 0,
            encounter: enc,
            currentIndex: 0,
            side: .allies,
            rngForInitiative: SeededPRNG(seed: 1),
            statuses: [:],
            mp: [:],
            equipment: [:]
        )
        var rng: any Randomizer = SeededPRNG(seed: 10)

        let firebolt = Ability<Character>(
            name: "Firebolt",
            costMP: 3,
            targeting: .firstFoe,
            effects: [
                AnyEffect(Damage<Character>(kind: .fire, base: 6, scale: { _ in 2 })),
                AnyEffect(ApplyStatus<Character>(Status(.staggered, duration: 1)))
            ]
        )

        var cast = Cast<Character>(firebolt)
        let before = rt.hp(of: gob)!
        let ev = cast.perform(in: &rt, rng: &rng)
        let after = rt.hp(of: gob)!

        #expect(after <= before)
        #expect(ev.contains { $0.kind == Event.Kind.statusApplied })
    }
}
