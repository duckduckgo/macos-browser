//
//  ArrayExtension.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

extension Array {

    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    func chunk(with limit: Int, offset: Int) -> [Element] {
        guard !isEmpty, limit >= 0, offset >= 0, offset < count else {
            return []
        }
        let endIndex = Swift.min(offset + limit, count)
        return Array(self[offset ..< endIndex])
    }

    /// Map collection insertion indexes for a filtered collection into a non-filtered collection
    /// Used to skip `stub` or `pendingDeletion` object indices in a full (non-filtered) database
    /// items collection and use insertion indexes of a filtered collection, the one that‘s displaying non-stub, non-deleted items.
    /// Stubs may appear in Sync when user has more than 1 device and they modify folder contents at or around the same time
    func adjustInsertionIndices(_ indices: IndexSet, isCountedItem: (Element) -> Bool) -> IndexSet {
        var storeIndex = 0
        var userIndex = 0
        var result = IndexSet()
        var shift = 0
        while userIndex <= indices.last ?? -1 {
            defer { storeIndex += 1 }
            guard !self.indices.contains(storeIndex) || isCountedItem(self[storeIndex]) else { continue }

            while indices.contains(userIndex) {
                result.insert(storeIndex + shift)
                shift += 1 // indices are shifted 1 up when item is inserted at the index
                userIndex += 1
            }
            userIndex += 1
        }
        return result
    }

}
