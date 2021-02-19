//
//  WebCacheManagerTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class WebCacheManagerTests: XCTestCase {

    func testWhenCookiesHaveSubDomainsOnSubDomainsAndWildcardsThenOnlyMatchingCookiesRetained() {
        let logins = MockPreservedLogins(domains: [
            "mobile.twitter.com"
        ])

        let dataStore = MockDataStore()
        dataStore.records = [
            MockDataRecord(recordName: "twitter.com"),
            MockDataRecord(recordName: "mobile.twitter.com"),
            MockDataRecord(recordName: "fake.mobile.twitter.com")
        ]

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5.0)

        XCTAssertEqual(dataStore.records.count, 2)
        XCTAssertEqual(dataStore.records[0].displayName, "twitter.com")
        XCTAssertEqual(dataStore.records[1].displayName, "mobile.twitter.com")
    }

    func testWhenClearedThenCookiesWithParentDomainsAreRetained() {

        let logins = MockPreservedLogins(domains: [
            "www.example.com"
        ])

        let dataStore = MockDataStore()
        dataStore.records = [
            MockDataRecord(recordName: "example.com"),
            MockDataRecord(recordName: "facebook.com")
        ]

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5.0)

        XCTAssertEqual(dataStore.records.count, 1)
        XCTAssertEqual(dataStore.records[0].displayName, "example.com")

    }

    func testWhenClearedThenDDGCookiesAreRetained() {
        let logins = MockPreservedLogins(domains: [
            "www.example.com"
        ])

        let dataStore = MockDataStore()
        dataStore.records = [
            MockDataRecord(recordName: "duckduckgo.com")
        ]

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5.0)

        XCTAssertEqual(dataStore.records.count, 1)
        XCTAssertEqual(dataStore.records[0].displayName, "duckduckgo.com")
    }

    func testWhenClearedThenCookiesForLoginsAreRetained() {
        let logins = MockPreservedLogins(domains: [
            "www.example.com"
        ])

        let dataStore = MockDataStore()
        dataStore.records = [
            MockDataRecord(recordName: "www.example.com"),
            MockDataRecord(recordName: "facebook.com")
        ]

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5.0)

        XCTAssertEqual(dataStore.records.count, 1)
        XCTAssertEqual(dataStore.records[0].displayName, "www.example.com")

    }

    func testWhenClearIsCalledThenCompletionIsCalled() {
        let dataStore = MockDataStore()
        let logins = MockPreservedLogins(domains: [])

        let expect = expectation(description: #function)
        WebCacheManager.shared.clear(dataStore: dataStore, logins: logins) {
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5.0)

        XCTAssertEqual(dataStore.removeAllDataCalledCount, 1)
    }

    // MARK: Mocks

    class MockDataStore: WebsiteDataStore {

        var records = [WKWebsiteDataRecord]()
        var removeAllDataCalledCount = 0

        func fetchDataRecords(ofTypes dataTypes: Set<String>, completionHandler: @escaping ([WKWebsiteDataRecord]) -> Void) {
            completionHandler(records)
        }

        func removeData(ofTypes dataTypes: Set<String>, for dataRecords: [WKWebsiteDataRecord], completionHandler: @escaping () -> Void) {
            removeAllDataCalledCount += 1
            self.records = records.filter { !dataRecords.contains($0) }
            completionHandler()
        }

    }

    class MockPreservedLogins: FireproofDomains {

        let domains: [String]

        override var fireproofDomains: [String] {
            return domains
        }

        init(domains: [String]) {
            self.domains = domains
        }

    }

    class MockDataRecord: WKWebsiteDataRecord {

        let recordName: String

        init(recordName: String) {
            self.recordName = recordName
        }

        override var displayName: String {
            recordName
        }

    }

}
