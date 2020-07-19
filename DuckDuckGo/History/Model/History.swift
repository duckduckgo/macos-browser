//
//  History.swift
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

class History {

    let historyStore: HistoryStore

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    convenience init () {
        self.init(historyStore: LocalHistoryStore())
    }

    func saveWebsiteVisit(url: URL, title: String?, date: Date) {
        let websiteVisit = WebsiteVisit(url: url, title: title, date: date)
        historyStore.saveWebsiteVisit(websiteVisit)
    }

}
