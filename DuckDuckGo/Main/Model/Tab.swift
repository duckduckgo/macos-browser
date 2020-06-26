//
//  Tab.swift
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

protocol TabActionDelegate: AnyObject {

    func tabForwardAction(_ tab: Tab)
    func tabBackAction(_ tab: Tab)
    func tabReloadAction(_ tab: Tab)

}

class Tab {

    @Published var url: URL?

    weak var actionDelegate: TabActionDelegate?

    func goForward() {
        actionDelegate?.tabForwardAction(self)
    }

    func goBack() {
        actionDelegate?.tabBackAction(self)
    }

    func reload() {
        actionDelegate?.tabReloadAction(self)
    }

}

extension Tab: Equatable {

    static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs === rhs
    }

}

extension Tab: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

}
