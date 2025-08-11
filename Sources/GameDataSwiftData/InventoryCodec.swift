//
//  InventoryCodec.swift
//  Fizzle
//
//  Created by Kyle Peterson on 8/10/25.
//

#if canImport(SwiftData)
import Foundation
import GameCore

enum InventoryCodec {
    struct DTO: Codable {
        let stacks: [String:Int]
    }

    static func encode(_ inv: Inventory) throws -> Data {
        try JSONEncoder().encode(DTO(stacks: inv.stacks))
    }

    static func decode(_ data: Data?) -> Inventory {
        guard
            let data, let dto = try? JSONDecoder().decode(DTO.self, from: data)
        else { return Inventory() }
        var inv = Inventory()
        for (id, qty) in dto.stacks { inv.add(id: id, qty: qty) }
        return inv
    }
}
#endif
