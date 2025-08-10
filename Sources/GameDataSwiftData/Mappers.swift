//
//  Mappers.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import GameCore

extension Race {
    init(_ e: RaceEntity) {
        self.init(id: e.id, name: e.name,
                  statBonuses: DictStatsCodec.decode(e.statBonuses),
                  tags: Set(e.tags))
    }
}

extension ClassDef {
    init(_ e: ClassEntity) {
        self.init(id: e.id,
                  name: e.name,
                  minStats: DictStatsCodec.decode(e.minStats),
                  allowedWeapons: Set(e.allowedWeapons),
                  allowedArmor: Set(e.allowedArmor),
                  startingTags: Set(e.startingTags),
                  startingLevel: e.startingLevel)
    }
}

extension Character {
    init(_ e: CharacterEntity) {
        self.init(name: e.name,
                  stats: StatsCodec.decode(e.stats),
                  tags: Set(e.tags))
    }
}
#endif
