//
//  BurnerMode.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import WebKit

// Identifies whether Tab or TabCollectionViewModel are regular or Burner (isolated)
// Also, it provides a way to pass shared website data store to related entities.
enum BurnerMode: Equatable {

    case regular
    case burner(websiteDataStore: WKWebsiteDataStore)

    init(isBurner: Bool) {
        if isBurner {
            // Each Burner Window has it's own independent website data store that
            // stores website data in memory
            self = .burner(websiteDataStore: .nonPersistent())
        } else {
            self = .regular
        }
    }

    var isBurner: Bool {
        switch self {
        case .regular: return false
        case .burner: return true
        }
    }

}
