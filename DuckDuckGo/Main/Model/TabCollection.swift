//
//  TabCollection.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

class TabCollection {

    @Published private(set) var tabs: [Tab] = []
    @Published var selectionIndex: Int?

    func prependNewTab() {
        prepend(tab: Tab())
    }

    func prepend(tab: Tab) {
        tabs.insert(tab, at: 0)
    }

}
