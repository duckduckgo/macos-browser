//
//  WebsiteDataStoreTests.swift
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

final class WebCacheManagerTests: XCTestCase {
    /// The webView is necessary to manage the shared state of WKWebsiteDataRecord
    var webView: WKWebView?

    override func setUp() {
        super.setUp()
        webView = WKWebView()
    }

    override func tearDown() {
        webView = nil
        super.tearDown()
    }

    func testWhenCookiesHaveSubDomainsOnSubDomainsAndWildcardsThenAllCookiesRetained() {
        let logins = MockPreservedLogins(domains: [
            "twitter.com"
        ])

        let cookieStore = MockHTTPCookieStore(cookies: [
            .make(domain: "twitter.com"),
            .make(domain: ".twitter.com"),
            .make(domain: "mobile.twitter.com"),
            .make(domain: "fake.mobile.twitter.com"),
            .make(domain: ".fake.mobile.twitter.com")
        ])

        let dataStore = MockDataStore()
        dataStore.cookieStore = cookieStore
        dataStore.records = [
            MockDataRecord(recordName: "twitter.com"),
            MockDataRecord(recordName: "mobile.twitter.com"),
            MockDataRecord(recordName: "fake.mobile.twitter.com")
        ]

        let expect = expectation(description: #function)
        let webCacheManager = WebCacheManager(fireproofDomains: logins, websiteDataStore: dataStore)
        Task {
            await webCacheManager.clear()
            expect.fulfill()
        }
        wait(for: [expect], timeout: 15.0)

        XCTAssertEqual(cookieStore.cookies.count, 5)
        XCTAssertEqual(cookieStore.cookies[0].domain, "twitter.com")
        XCTAssertEqual(cookieStore.cookies[1].domain, ".twitter.com")
        XCTAssertEqual(cookieStore.cookies[2].domain, "mobile.twitter.com")
        XCTAssertEqual(cookieStore.cookies[3].domain, "fake.mobile.twitter.com")
        XCTAssertEqual(cookieStore.cookies[4].domain, ".fake.mobile.twitter.com")
    }

    func testWhenClearedThenCookiesWithParentDomainsAreRetained() {

        let logins = MockPreservedLogins(domains: [
            "example.com"
        ])

        let cookieStore = MockHTTPCookieStore(cookies: [
            .make(domain: ".example.com"),
            .make(domain: "facebook.com")
        ])

        let dataStore = MockDataStore()
        dataStore.cookieStore = cookieStore
        dataStore.records = [
            MockDataRecord(recordName: "example.com"),
            MockDataRecord(recordName: "facebook.com")
        ]

        let expect = expectation(description: #function)
        let webCacheManager = WebCacheManager(fireproofDomains: logins, websiteDataStore: dataStore)
        Task {
            await webCacheManager.clear()
            expect.fulfill()
        }
        wait(for: [expect], timeout: 30.0)

        XCTAssertEqual(cookieStore.cookies.count, 1)
        XCTAssertEqual(cookieStore.cookies[0].domain, ".example.com")

    }

    @MainActor func testWhenClearedThenDDGCookiesAndStorageAreRetained() async {
        let logins = MockPreservedLogins(domains: [
            "example.com"
        ])

        let cookieStore = MockHTTPCookieStore(cookies: [
            .make(domain: "duckduckgo.com")
        ])

        let dataStore = MockDataStore()
        dataStore.cookieStore = cookieStore
        dataStore.records = [
            MockDataRecord(recordName: "duckduckgo.com")
        ]

        let webCacheManager = WebCacheManager(fireproofDomains: logins, websiteDataStore: dataStore)

        // Await the clear function directly
        await webCacheManager.clear()

        // Assertions after the async operation
        XCTAssertEqual(cookieStore.cookies.count, 1)
        XCTAssertEqual(cookieStore.cookies[0].domain, "duckduckgo.com")

        XCTAssertEqual(dataStore.records.count, 1)
        XCTAssertEqual(dataStore.records.first?.displayName, "duckduckgo.com")
    }

    func testWhenClearedThenCookiesForLoginsAreRetained() {
        let logins = MockPreservedLogins(domains: [
            "example.com"
        ])

        let cookieStore = MockHTTPCookieStore(cookies: [
            .make(domain: "www.example.com"),
            .make(domain: "facebook.com")
        ])

        let dataStore = MockDataStore()
        dataStore.cookieStore = cookieStore
        dataStore.records = [
            MockDataRecord(recordName: "www.example.com"),
            MockDataRecord(recordName: "facebook.com")
        ]

        let expect = expectation(description: #function)
        let webCacheManager = WebCacheManager(fireproofDomains: logins, websiteDataStore: dataStore)
        Task {
            await webCacheManager.clear()
            expect.fulfill()
        }
        wait(for: [expect], timeout: 30.0)

        XCTAssertEqual(cookieStore.cookies.count, 1)
        XCTAssertEqual(cookieStore.cookies[0].domain, "www.example.com")
    }

    func testWhenClearIsCalledThenCompletionIsCalled() {
        let dataStore = MockDataStore()
        let logins = MockPreservedLogins(domains: [])

        let expect = expectation(description: #function)
        let webCacheManager = WebCacheManager(fireproofDomains: logins, websiteDataStore: dataStore)
        Task {
            await webCacheManager.clear()
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5.0)

        XCTAssertEqual(dataStore.removeDataCalledCount, 2)
    }

    // MARK: Mocks

    class MockDataStore: WebsiteDataStore {

        var cookieStore: HTTPCookieStore?
        var records = [WKWebsiteDataRecord]()
        var removeDataCalledCount = 0

        func dataRecords(ofTypes dataTypes: Set<String>) async -> [WKWebsiteDataRecord] {
            return records
        }

        func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date) async {
            removeDataCalledCount += 1

            // In the real implementation, records will be selectively removed or edited based on their Fireproof status. For simplicity in this test,
            // only remove records if all data types are removed, so that we can tell whether records for given domains still exist in some form.
            if dataTypes == WKWebsiteDataStore.allWebsiteDataTypes() {
                self.records = records.filter {
                    dataTypes == $0.dataTypes
                }
            }
        }

        func removeData(ofTypes dataTypes: Set<String>, for recordsToRemove: [WKWebsiteDataRecord]) async {
            removeDataCalledCount += 1

            self.records = self.records.filter { record in
                !recordsToRemove.contains(where: { $0 == record && $0.dataTypes.isSubset(of: dataTypes)})
            }
        }

        func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date, completionHandler: @escaping () -> Void) {
            removeDataCalledCount += 1

            completionHandler()
        }

    }

    class MockPreservedLogins: FireproofDomains {

        init(domains: [String]) {
            super.init(store: FireproofDomainsStoreMock())

            for domain in domains {
                super.add(domain: domain)
            }
        }

    }

    class MockDataRecord: WKWebsiteDataRecord {

        let recordName: String
        let recordTypes: Set<String>

        init(recordName: String, types: Set<String> = WKWebsiteDataStore.allWebsiteDataTypes()) {
            self.recordName = recordName
            self.recordTypes = types
        }

        override var displayName: String {
            recordName
        }

        override var dataTypes: Set<String> {
            recordTypes
        }

    }

    class MockHTTPCookieStore: HTTPCookieStore {

        var cookies: [HTTPCookie]

        init(cookies: [HTTPCookie] = []) {
            self.cookies = cookies
        }

        func allCookies() async -> [HTTPCookie] {
            return cookies
        }

        func setCookie(_ cookie: HTTPCookie) async {
            cookies.append(cookie)
        }

        func deleteCookie(_ cookie: HTTPCookie) async {
            cookies.removeAll { $0.domain == cookie.domain }
        }

    }

}
