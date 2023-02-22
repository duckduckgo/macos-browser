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
        return url.host!
    }

    override func tearDownWithError() throws {
        referenceTests.removeAll()
    }

    func testFireproofing() throws {
        referenceTests = testData.fireButtonFireproofing.tests.filter {
            $0.exceptPlatforms.contains("macos-browser") == false
        }

        let testsExecuted = expectation(description: "tests executed")
        testsExecuted.expectedFulfillmentCount = referenceTests.count

        runReferenceTests(onTestExecuted: testsExecuted)

        waitForExpectations(timeout: 30, handler: nil)
    }

    private func runReferenceTests(onTestExecuted: XCTestExpectation) {

        guard let test = referenceTests.popLast() else {
            return
        }

        os_log("Testing %s", test.name)

        let loginDomains = testData.fireButtonFireproofing.fireproofedSites.map { sanitizedSite($0) }
        let logins = MockPreservedLogins(domains: loginDomains)

        let webCacheManager = WebCacheManager(fireproofDomains: logins, websiteDataStore: dataStore)

        guard let cookie = cookie(for: test) else {
            XCTFail("Cookie should exist for test \(test.name)")
            return
        }

        Task { @MainActor () -> Void in
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

            DispatchQueue.main.async { [weak self] in
                onTestExecuted.fulfill()

                guard let self = self else {
                    XCTFail("\(#function): Failed to unwrap self")
                    return
                }

                self.runReferenceTests(onTestExecuted: onTestExecuted)
            }
        }
    }

    private func cookie(for test: Test) -> HTTPCookie? {
        HTTPCookie(properties: [.name: test.cookieName,
                                .path: "",
                                .domain: test.cookieDomain,
                                .value: "123"])
    }

    private class MockPreservedLogins: FireproofDomains {

        init(domains: [String]) {
            super.init(store: FireproofDomainsStoreMock())

            for domain in domains {
                super.add(domain: domain)
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
