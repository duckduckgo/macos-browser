//
//  KeySetDictionary.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

struct KeySetDictionary<Key: Hashable, Value>: ExpressibleByDictionaryLiteral {

    private var dict = [Key: Value]()
    private(set) var keys = Set<Key>()

    init () {}

    init(dictionaryLiteral elements: (Key, Value)...) {
        for (key, value) in elements {
            self[key] = value
        }
    }

    subscript(key: Key) -> Value? {
        get {
            return dict[key]
        }
        set {
            dict[key] = newValue
            if newValue != nil {
                keys.insert(key)
            } else {
                keys.remove(key)
            }
        }
    }

    mutating func removeValue(forKey key: Key) -> Value? {
        keys.remove(key)
        return dict.removeValue(forKey: key)
    }

}
