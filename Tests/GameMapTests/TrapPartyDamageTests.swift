//
//  TrapPartyDamageTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameMap
@testable import GameCore

// Reference wrapper to mutate party safely from a @Sendable closure in tests.
final class PartyBox: @unchecked Sendable {
    var members: [Character]
    init(_ m: [Character]) { self.members = m }
    func applyDamage(_ dmg: Int) {
        for i in members.indices { members[i].stats.add(.hp, -dmg) }
    }
}

@Suite struct TrapPartyDamageTests {

    @Test
    func movementTrapDamagesAllPartyMembers() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .trap(
            id: "spike",
            detectDC: 60, disarmDC: 60,
            damage: 8,
            once: true,
            armed: true
        )

        // Party in a reference box so we can mutate from a @Sendable closure.
        let partyBox = PartyBox([
            Character(name: "Hero", stats: StatBlock([.hp: 30, .vit: 5])),
            Character(name: "Mage", stats: StatBlock([.hp: 22, .int: 8]))
        ])

        let applyTrapToParty: TrapDamageHandler = { dmg in
            partyBox.applyDamage(dmg)
        }

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 123)

        // NOTE: pass resolver: nil explicitly to match the new signature.
        let result = rt.moveForward(resolver: nil, rng: &rng, trapDamageHandler: applyTrapToParty)

        #expect(result.trapDamage == 8)
        #expect(partyBox.members[0].stats[.hp] == 22) // 30 - 8
        #expect(partyBox.members[1].stats[.hp] == 14) // 22 - 8
        #expect(rt.map[GridCoord(1,0)].feature == .none) // once=true cleared
    }

    @Test
    func interactTriggeredTrapAlsoDamagesParty() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .trap(
            id: "needle",
            detectDC: 90, disarmDC: 90,
            damage: 5,
            once: true,
            armed: true
        )

        let partyBox = PartyBox([
            Character(name: "Rogue",  stats: StatBlock([.hp: 25])),
            Character(name: "Priest", stats: StatBlock([.hp: 18]))
        ])

        let applyTrap: TrapDamageHandler = { dmg in
            partyBox.applyDamage(dmg)
        }

        // Poor skills → likely to fail and trigger
        let cat = BuiltInSkills.demoCatalog()
        var sheet = SkillSheet()
        sheet.addRanks(BuiltInSkills.perception, 5, using: cat)
        sheet.addRanks(BuiltInSkills.disarm, 5, using: cat)

        struct Resolver: SkillResolver {
            let sheet: SkillSheet; let cat: SkillCatalog
            func check(id: SkillID, dc: Int, rng: inout any Randomizer) -> SkillOutcome {
                SkillSystem.check(id: id, sheet: sheet, catalog: cat, dc: dc, rng: &rng)
            }
        }

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 7)

        let out = rt.interactAhead(
            resolver: Resolver(sheet: sheet, cat: cat),
            rng: &rng,
            trapDamageHandler: applyTrap
        )

        switch out {
        case .trapTriggered(damage: let d):
            #expect(d == 5)
            #expect(partyBox.members[0].stats[.hp] == 20)
            #expect(partyBox.members[1].stats[.hp] == 13)
            #expect(rt.map[GridCoord(1,0)].feature == .none)
        default:
            #expect(Bool(false), "Expected trapTriggered")
        }
    }
}
