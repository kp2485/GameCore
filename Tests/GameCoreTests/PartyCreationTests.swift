//
//  PartyCreationTests.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation
import Testing
@testable import GameCore

private func envFixture() -> GameEnvironment {
    let human = Race(id: "human", name: "Human", statBonuses: [.str: 1, .int: 1])
    let dwarf = Race(id: "dwarf", name: "Dwarf", statBonuses: [.vit: 2], tags: ["stout"])
    let fighter = ClassDef(id: "fighter", name: "Fighter",
                           minStats: [.str: 6, .vit: 6],
                           allowedWeapons: ["blade", "blunt"],
                           allowedArmor: ["light", "heavy"],
                           startingTags: ["martial"])
    let mage = ClassDef(id: "mage", name: "Mage",
                        minStats: [.int: 7],
                        allowedWeapons: ["staff"],
                        allowedArmor: ["robe"],
                        startingTags: ["arcane"])

    let races = InMemoryRaceRepository([human, dwarf])
    let classes = InMemoryClassRepository([fighter, mage])
    return GameEnvironment(races: races, classes: classes)
}

@Suite struct PartyCreationTests {

    @Test func createFighterSucceedsWithBonuses() throws {
        let env = envFixture()
        let builder = PartyBuilder(env: env, rules: .init(startingPoints: 20, minPerStat: 1, maxPerStat: 18))
        let spec = CreationSpec(
            name: "Brom",
            raceId: "human",        // +1 STR, +1 INT
            classId: "fighter",     // requires STR 6, VIT 6
            baseStats: [.str: 5, .vit: 6, .agi: 3, .int: 0, .spi: 2, .luc: 2]
        )
        let c = try builder.buildCharacter(from: spec)
        #expect(c.name == "Brom")
        #expect(c.stats[.str] == 6) // 5 base +1 race
        #expect(c.tags.contains("class:fighter"))
        #expect(c.stats[.hp] == c.stats.maxHP)
        #expect(c.stats[.mp] == c.stats.maxMP)
    }

    @Test func classRequirementEnforced() {
        let env = envFixture()
        let builder = PartyBuilder(env: env, rules: .init(startingPoints: 20, minPerStat: 1, maxPerStat: 18))
        let spec = CreationSpec(
            name: "Merel",
            raceId: "human",
            classId: "mage",        // needs INT 7
            baseStats: [.int: 5]    // +1 race → 6 (still too low)
        )
        do {
            _ = try builder.buildCharacter(from: spec)
            #expect(Bool(false), "Expected failure for INT requirement")
        } catch CreationError.statBelowRequirement(let stat, let have, let need) {
            #expect(stat == .int)
            #expect(have == 6)
            #expect(need == 7)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func pointBudgetIsValidated() {
        let env = envFixture()
        let builder = PartyBuilder(env: env, rules: .init(startingPoints: 10, minPerStat: 1, maxPerStat: 18))
        let spec = CreationSpec(
            name: "Overcap",
            raceId: "dwarf",
            classId: "fighter",
            baseStats: [.str: 8, .vit: 8]  // 16 > 10
        )
        do {
            _ = try builder.buildCharacter(from: spec)
            #expect(Bool(false), "Expected point budget failure")
        } catch CreationError.totalPointsExceeded(let allowed, let got) {
            #expect(allowed == 10)
            #expect(got == 16)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func buildPartyFromSpecs() throws {
        let env = envFixture()
        let builder = PartyBuilder(env: env)
        let a = CreationSpec(name: "Dara", raceId: "human", classId: "fighter", baseStats: [.str: 6, .vit: 6])
        let b = CreationSpec(name: "Irin", raceId: "dwarf", classId: "mage", baseStats: [.int: 7, .spi: 3])
        let party = try builder.buildParty(from: [a, b])
        #expect(party.count == 2)
        #expect(party[0].name == "Dara")
        #expect(party[1].tags.contains("race:dwarf"))
    }
}
