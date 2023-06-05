//
//  String+ArrayConversion.swift
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

// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation

extension String {

    func splitToArray(separator: Character = ",", trimmingCharacters: CharacterSet? = nil) -> [String] {
        return split(separator: separator)
            .map {
                if let charSet = trimmingCharacters {
                    return $0.trimmingCharacters(in: charSet)
                } else {
                    return String($0)
                }
        }
    }

}

extension Optional where Wrapped == String {

    func splitToArray(separator: Character = ",", trimmingCharacters: CharacterSet? = nil) -> [String] {
        switch self {
        case .none:
            return []
        case .some(let wrapped):
            return wrapped.splitToArray(separator: separator, trimmingCharacters: trimmingCharacters)
        }
    }

}
