//
//  FindInPageModel.swift
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

class FindInPageModel {

    @Published private(set) var text: String = ""
    @Published private(set) var currentSelection: Int = 1
    @Published private(set) var matchesFound: Int = 0

    let id = UUID.init().uuidString

    func next() {
        let nextSelection = currentSelection + 1
        if nextSelection > matchesFound {
            currentSelection = 1
        } else {
            currentSelection = nextSelection
        }
    }

    func previous() {
        let nextSelection = currentSelection - 1
        if nextSelection < 1 {
            currentSelection = matchesFound
        } else {
            currentSelection = nextSelection
        }
    }

    func update(text: String, matchesFound: Int) {
        self.text = text
        self.matchesFound = matchesFound
        self.currentSelection = 1
    }

}
