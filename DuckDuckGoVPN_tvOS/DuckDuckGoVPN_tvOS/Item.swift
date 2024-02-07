//
//  Item.swift
//  DuckDuckGoVPN_tvOS
//
//  Created by ddg on 2/6/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
