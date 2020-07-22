//
//  HistoryStoreTests.swift
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

class LocalHistoryStoreTests: XCTestCase {

    var database: Database = {
        let aplicationSupportDirectoryUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let databaseFileUrl = aplicationSupportDirectoryUrl.appendingPathComponent("TestDatabase.sqlite")
        return Database(fileUrl: databaseFileUrl)
    }()

    func testWhenAllWebsiteVisitsAreRemovedThenNoWebsiteVisitsAreLoaded() {
        let historyStore = LocalHistoryStore(database: database)
        historyStore.removeAllWebsiteVisits()

        historyStore.loadWebsiteVisits(textQuery: nil, limit: 1) { (websiteVisits, error) in
            XCTAssertEqual(websiteVisits?.count, 0)
            XCTAssertNil(error)
        }
    }

    func testWhenWebsiteVisitIsSavedThenItMustBeLoadedFromTheStore() {
        let historyStore = LocalHistoryStore(database: database)
        historyStore.removeAllWebsiteVisits()

        let aWebsiteVisit = WebsiteVisit.duckDuckGoVisit
        historyStore.saveWebsiteVisit(aWebsiteVisit)

        historyStore.loadWebsiteVisits(textQuery: nil, limit: 100) { (websiteVisits, error) in
            XCTAssertEqual(websiteVisits?.count, 1)
            XCTAssertNil(error)

            let websiteVisit = websiteVisits?.first
            XCTAssertEqual(websiteVisit?.url, aWebsiteVisit.url)
            XCTAssertEqual(websiteVisit?.title, aWebsiteVisit.title)
            XCTAssertEqual(websiteVisit?.date, aWebsiteVisit.date)
        }
    }

    func testWhenStringQueryIsPassedThenResultMustMatchIt() {
        let historyStore = LocalHistoryStore(database: database)
        historyStore.removeAllWebsiteVisits()

        let aWebsiteVisit1 = WebsiteVisit.duckDuckGoVisit
        historyStore.saveWebsiteVisit(aWebsiteVisit1)
        let aWebsiteVisit2 = WebsiteVisit.spreadPrivacyVisit
        historyStore.saveWebsiteVisit(aWebsiteVisit2)

        historyStore.loadWebsiteVisits(textQuery: "privacy", limit: 100) { (websiteVisits, error) in
            XCTAssertEqual(websiteVisits?.count, 1)
            XCTAssertNil(error)
        }
    }

}

fileprivate extension WebsiteVisit {

    static let duckDuckGoVisit: WebsiteVisit = {
        WebsiteVisit(url: URL.duckDuckGo, title: "DuckDuckGo", date: Date(timeIntervalSince1970: 0))
    }()

    static let spreadPrivacyVisit: WebsiteVisit = {
        WebsiteVisit(url: URL(string: "https://spreadprivacy.com")!, title: "DuckDuckGo Blog", date: Date(timeIntervalSince1970: 0))
    }()

}
