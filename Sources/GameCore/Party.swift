//
//  Party.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//


import Foundation

/// Ordered collection of actors (front to back or slot order).
public struct Party<A: GameActor>: Sendable, Equatable {
    public var members: [A]

    public init(_ members: [A]) { self.members = members }

    public var isEmpty: Bool { members.isEmpty }
    public var count: Int { members.count }

    public subscript(index: Int) -> A { members[index] }
}
