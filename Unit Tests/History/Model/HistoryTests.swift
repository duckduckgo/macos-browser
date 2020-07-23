//
//  HistoryTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class HistoryTests: XCTestCase {

    func testWhenSaveWebsiteVisitIsCalledThenTheWebsiteVisitIsStored() {
        let historyStoreMock = HistoryStoreMock()
        let history = History(historyStore: historyStoreMock)

        let url = URL.duckDuckGo
        let title = "title"
        let date = NSDate.now as Date
        history.saveWebsiteVisit(url: url, title: title, date: date)

        XCTAssertEqual(historyStoreMock.savedWebsiteVisit?.url, url)
        XCTAssertEqual(historyStoreMock.savedWebsiteVisit?.title, title)
        XCTAssertEqual(historyStoreMock.savedWebsiteVisit?.date, date)
    }

    func testWhenClearIsCalledThenHistoryStoreIsCleared() {
        let historyStoreMock = HistoryStoreMock()
        let history = History(historyStore: historyStoreMock)

        history.clear()
        XCTAssertTrue(historyStoreMock.removeAllWebsiteVisitsCalled)
    }

}
