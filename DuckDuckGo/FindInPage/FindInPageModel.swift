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
import WebKit

final class FindInPageModel {

    @Published private(set) var text: String = ""
    @Published private(set) var currentSelection: UInt?
    @Published private(set) var matchesFound: UInt?
    @Published private(set) var isVisible: Bool = false

    func update(currentSelection: UInt?, matchesFound: UInt?) {
        self.currentSelection = currentSelection
        self.matchesFound = matchesFound
    }

    func show() {
        isVisible = true
    }

    func close() {
        isVisible = false
    }

    func find(_ text: String) {
        self.text = text
    }

}
