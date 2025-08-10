//
//  StatsCodec.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import GameCore

/// Convert between StatBlock<CoreStat> and compact [Int] aligned to CoreStat.allCases.
enum StatsCodec {
    static func encode(_ block: StatBlock<CoreStat>) -> [Int] {
        CoreStat.allCases.map { block[$0] }
    }
    static func decode(_ arr: [Int]) -> StatBlock<CoreStat> {
        var out = StatBlock<CoreStat>()
        for (i, k) in CoreStat.allCases.enumerated() {
            out[k] = (i < arr.count) ? arr[i] : 0
        }
        return out
    }
}

/// Convert race/class stat dictionaries into fixed arrays.
enum DictStatsCodec {
    static func encode(_ dict: [CoreStat: Int]) -> [Int] {
        CoreStat.allCases.map { dict[$0] ?? 0 }
    }
    static func decode(_ arr: [Int]) -> [CoreStat: Int] {
        var out: [CoreStat: Int] = [:]
        for (i, k) in CoreStat.allCases.enumerated() {
            out[k] = (i < arr.count) ? arr[i] : 0
        }
        return out
    }
}
#endif
