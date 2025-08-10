//
//  Utility.swift
//  GameCore
//
//  Created by Kyle Peterson on 8/10/25.
//

import Foundation

@inlinable public func clamp<T: Comparable>(_ x: T, _ a: T, _ b: T) -> T { min(max(x, a), b) }
