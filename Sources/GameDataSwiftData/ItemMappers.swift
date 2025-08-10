//
//  ItemMappers.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import GameCore

// Map persisted models -> runtime Items/Equipment
enum ItemMapper {

    static func toRuntimeWeapon(_ e: ItemEntity) -> Weapon {
        let sk = ScalingKind(rawValue: e.scalingKind) ?? .none
        switch sk {
        case .none:
            return Weapon(id: e.id, name: e.name, tags: Set(e.tags), baseDamage: e.baseDamage, scale: { _ in 0 })
        case .strDivisor:
            let d = max(1, e.scalingParam)
            return Weapon(id: e.id, name: e.name, tags: Set(e.tags), baseDamage: e.baseDamage, scale: { $0.stats[.str] / d })
        }
    }

    static func toRuntimeArmor(_ e: ItemEntity) -> Armor {
        Armor(id: e.id, name: e.name, tags: Set(e.tags), mitigationPercent: e.mitigationPercent)
    }

    static func toRuntimeItem(_ e: ItemEntity) -> any Item {
        switch ItemKind(rawValue: e.kind) ?? .weapon {
            case .weapon: return toRuntimeWeapon(e)
            case .armor:  return toRuntimeArmor(e)
        }
    }
}
#endif
