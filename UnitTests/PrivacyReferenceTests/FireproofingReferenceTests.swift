//
//  FireproofingReferenceTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import os.log
@testable import DuckDuckGo_Privacy_Browser
import Common

final class FireproofingReferenceTests: XCTestCase {
    private var referenceTests = [Test]()
    private let dataStore = WKWebsiteDataStore.default()
    private let fireproofDomains = FireproofDomains.shared

    private enum Resource {
        static let tests = "privacy-reference-tests/storage-clearing/tests.json"
    }

    private lazy var testData: TestData = {
        let bundle = Bundle(for: BrokenSiteReportingReferenceTests.self)
        let testData: TestData = PrivacyReferenceTestHelper().decodeResource(Resource.tests, from: bundle)
        return testData
    }()

    private func sanitizedSite(_ site: String) -> String {
        let url = URL(string: site)!
        return url.host ?? site
    }

    override func tearDownWithError() throws {
        referenceTests.removeAll()
    }

    /// Test disabled until Privacy Reference Tests contain the new Fire Button and Fireproofing logic
    @MainActor
    func testFireproofing() async throws {
        referenceTests = testData.fireButtonFireproofing.tests.filter {
            $0.exceptPlatforms.contains("macos-browser") == false
        }

        for test in referenceTests {
            await runReferenceTest(test)
        }
    }

    @MainActor
    private func runReferenceTest(_ test: Test) async {
        Logger.general.debug("Testing \(test.name)")

        let loginDomains = testData.fireButtonFireproofing.fireproofedSites.map { sanitizedSite($0) }
        let logins = MockPreservedLogins(domains: loginDomains, tld: ContentBlocking.shared.tld)

        let webCacheManager = WebCacheManager(fireproofDomains: logins, websiteDataStore: dataStore)

        guard let cookie = cookie(for: test) else {
            XCTFail("Cookie should exist for test \(test.name)")
            return
        }

        await dataStore.cookieStore?.setCookie(cookie)
        await webCacheManager.clear()

        let hotCookies = await dataStore.cookieStore?.allCookies()
        let testCookie = hotCookies?.filter { $0.name == test.cookieName }.first

        if test.expectCookieRemoved {
            XCTAssertNil(testCookie, "Cookie should not exist for test: \(test.name)")
        } else {
            XCTAssertNotNil(testCookie, "Cookie should exist for test: \(test.name)")
        }

        if let cookie = testCookie {
            await dataStore.cookieStore?.deleteCookie(cookie)
        }
    }

    private func cookie(for test: Test) -> HTTPCookie? {
        HTTPCookie(properties: [.name: test.cookieName,
                                .path: "",
                                .domain: test.cookieDomain,
                                .value: "123"])
    }

    private class MockPreservedLogins: FireproofDomains {

        init(domains: [String], tld: TLD) {
            super.init(store: FireproofDomainsStoreMock())

            for domain in domains {
                guard let eTLDPlusOne = tld.eTLDplus1(domain) else {
                    XCTFail("Can't create eTLD+1 domain for \(domain). TLDs: \(Mirror(reflecting: tld).children.first(where: { $0.label == "tlds" }).map { String(describing: $0.value) } ?? "<nil>")")
                    return
                }
                super.add(domain: eTLDPlusOne)
            }
        }
    }
}

// MARK: - TestData
private struct TestData: Codable {
    let fireButtonFireproofing: FireButtonFireproofing
}

// MARK: - FireButtonFireproofing
private struct FireButtonFireproofing: Codable {
    let name, desc: String
    let fireproofedSites: [String]
    let tests: [Test]
}

// MARK: - Test
private struct Test: Codable {
    let name, cookieDomain, cookieName: String
    let expectCookieRemoved: Bool
    let exceptPlatforms: [String]
}
