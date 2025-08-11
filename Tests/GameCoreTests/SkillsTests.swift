//
//  SkillsTests.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameCore

@Suite struct SkillsTests {

    @Test
    func sheetTotalsAndCaps() {
        var sheet = SkillSheet()
        let cat = BuiltInSkills.demoCatalog()

        sheet.addRanks(BuiltInSkills.sword, 80, using: cat)
        sheet.addBonus(BuiltInSkills.sword, 10)
        #expect(sheet.rank(of: BuiltInSkills.sword) == 80)
        #expect(sheet.total(of: BuiltInSkills.sword, using: cat) == 90)

        // Respect cap at 100 for ranks, but allow bonus on top.
        sheet.addRanks(BuiltInSkills.sword, 50, using: cat) // rank clamps to 100
        #expect(sheet.rank(of: BuiltInSkills.sword) == 100)

        // Overwrite the previous +10 with +15 (not additive in this case)
        sheet.setBonus(BuiltInSkills.sword, 15)
        #expect(sheet.total(of: BuiltInSkills.sword, using: cat) == 115)
    }

    @Test
    func deterministicCheckPassFail() {
        var rng: any Randomizer = SeededPRNG(seed: 123)
        var sheet = SkillSheet()
        let cat = BuiltInSkills.demoCatalog()
        sheet.addRanks(BuiltInSkills.lockpicking, 60, using: cat) // good but not perfect

        // Moderate DC 50 → roughly roll-under total
        let r1 = SkillSystem.check(id: BuiltInSkills.lockpicking, sheet: sheet, catalog: cat, dc: 50, rng: &rng)
        switch r1 {
        case .success(_, _), .critical(_): break
        default: #expect(Bool(false), "Expected a success-like outcome")
        }

        // Hard DC 80 → many failures expected
        var r2count = 0
        for _ in 0..<20 {
            let r = SkillSystem.check(id: BuiltInSkills.lockpicking, sheet: sheet, catalog: cat, dc: 80, rng: &rng)
            if case .fail(_, _) = r { r2count += 1 }
        }
        #expect(r2count > 0)
    }

    @Test
    func opposedCheck() {
        var rng: any Randomizer = SeededPRNG(seed: 7)
        var a = SkillSheet(), d = SkillSheet()
        let cat = BuiltInSkills.demoCatalog()
        a.addRanks(BuiltInSkills.archery, 70, using: cat)
        d.addRanks(BuiltInSkills.stealth, 50, using: cat)

        let result = SkillSystem.opposed(attacker: (BuiltInSkills.archery, a),
                                         defender: (BuiltInSkills.stealth, d),
                                         catalog: cat,
                                         rng: &rng)
        #expect(result.attackerWins) // With these seeds and totals, attacker should win often
    }
}
