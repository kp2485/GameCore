//
//  Status.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

/// Simple time-based status with stacking & tags.
/// Extend later with dispel types, periodic ticks, etc.
public struct Status: Hashable, Sendable {
    public enum Id: String, Sendable { case staggered, regen, shield }
    public enum StackRule: Sendable, Equatable, Hashable { case replace, stack(Int) }

    public let id: Id
    public let duration: Int
    public let stacks: Int
    public let rule: StackRule

    public init(_ id: Id, duration: Int, stacks: Int = 1, rule: StackRule = .replace) {
        precondition(duration >= 1 && stacks >= 1)
        self.id = id; self.duration = duration; self.stacks = stacks; self.rule = rule
    }

    public func refreshed(applying other: Status) -> Status {
        precondition(id == other.id)
        switch rule {
        case .replace:
            return Status(id, duration: max(duration, other.duration), stacks: 1, rule: rule)
        case .stack(let maxStacks):
            let newStacks = min(maxStacks, stacks + other.stacks)
            let newDur = max(duration, other.duration)
            return Status(id, duration: newDur, stacks: newStacks, rule: rule)
        }
    }

    public func ticked() -> Status? {
        let d = duration - 1
        return d > 0 ? Status(id, duration: d, stacks: stacks, rule: rule) : nil
    }
}
