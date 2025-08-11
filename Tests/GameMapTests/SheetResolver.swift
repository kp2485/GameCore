//
//  SheetResolver.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

import Testing
@testable import GameMap
@testable import GameCore

private struct SheetResolver: SkillResolver {
    let sheet: SkillSheet
    let catalog: SkillCatalog
    func check(id: SkillID, dc: Int, rng: inout any Randomizer) -> SkillOutcome {
        SkillSystem.check(id: id, sheet: sheet, catalog: catalog, dc: dc, rng: &rng)
    }
}

@Suite struct SkillInteractionTests {
    @Test
    func lockpickingOnLockedDoor() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .door(locked: true, secret: false)

        // Build a skilled lockpicker
        var sheet = SkillSheet()
        let cat = BuiltInSkills.demoCatalog()
        sheet.addRanks(BuiltInSkills.lockpicking, 80, using: cat)

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 123)
        let outcome = rt.interactAhead(resolver: SheetResolver(sheet: sheet, catalog: cat), rng: &rng)

        switch outcome {
        case .lockpickSuccess, .doorOpened: break
        default: #expect(Bool(false), "Expected lockpickSuccess/doorOpened, got \(outcome)")
        }
    }

    @Test
    func lockpickingFailsWithLowSkill() {
        var map = GameMap(id: "m", name: "M", width: 2, height: 1, fill: Cell())
        map[GridCoord(1,0)].feature = .door(locked: true, secret: false)

        var sheet = SkillSheet()
        let cat = BuiltInSkills.demoCatalog()
        sheet.addRanks(BuiltInSkills.lockpicking, 10, using: cat)

        var rt = MapRuntime(map: map, start: GridCoord(0,0), facing: .east)
        var rng: any Randomizer = SeededPRNG(seed: 1)
        let outcome = rt.interactAhead(resolver: SheetResolver(sheet: sheet, catalog: cat), rng: &rng)

        switch outcome {
        case .lockpickFailed(_), .doorLocked: break
        default: #expect(Bool(false), "Expected failure/locked")
        }
    }
}
