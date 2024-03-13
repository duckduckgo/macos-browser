//
//  FireproofDomainsTests.swift
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

final class FireproofDomainsTests: XCTestCase {
    let store = FireproofDomainsStoreMock()
    lazy var logins: FireproofDomains = FireproofDomains(store: store, tld: ContentBlocking.shared.tld)

    override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()
    }

    func testWhenFireproofDomainsContainsFireproofedDomainThenReturnsTrue() {
        XCTAssertFalse(logins.isFireproof(fireproofDomain: "example.com"))
        logins.add(domain: "example.com")
        XCTAssertTrue(logins.isFireproof(fireproofDomain: "www.example.com"))
    }

    func testWhenFireproofDomainsContainsFireproofedDomainThenIsURLFireproofReturnsTrue() {
        XCTAssertFalse(logins.isFireproof(fireproofDomain: "example.com"))
        logins.add(domain: "example.com")
        XCTAssertTrue(logins.isURLFireproof(url: URL(string: "http://www.example.com/example")!))
    }

    func testWhenFireproofDomainsDoesNotContainDomainThenIsURLFireproofReturnsFalse() {
        XCTAssertFalse(logins.isFireproof(fireproofDomain: "thisisexample.com"))
        logins.add(domain: "thisisexample.com")
        XCTAssertFalse(logins.isURLFireproof(url: URL(string: "http://www.example.com/example")!))
    }

    func testWhenFireproofDomainsContainsCookieDomainThenIsCookieDomainFireproofReturnsTrue() {
        logins.add(domain: "www.example.com")
        XCTAssertTrue(logins.isFireproof(cookieDomain: "example.com"))
    }

    func testWhenFireproofDomainsContainsCookieDomainThenDotPrefixedIsCookieDomainFireproofReturnsTrue() {
        logins.add(domain: "www.example.com")
        XCTAssertTrue(logins.isFireproof(cookieDomain: ".example.com"))
    }

    func testWhenFireproofDomainsContainsCookieSubdomainThenDotPrefixedIsCookieDomainFireproofReturnsTrue() {
        logins.add(domain: "www.sub.example.com")
        XCTAssertTrue(logins.isFireproof(cookieDomain: ".example.com"))
    }

    func testWhenFireproofDomainsDoesNotContainCookieDomainThenIsCookieDomainFireproofReturnsFalse() {
        logins.add(domain: "thisisexample.com")
        XCTAssertFalse(logins.isFireproof(cookieDomain: "example.com"))
    }

    func testWhenNewThenFireproofDomainsIsEmpty() {
        XCTAssertTrue(logins.fireproofDomains.isEmpty)
    }

    func testWhenFireproofedDomainsInUserDefaultsThenMigrationIsPerformed() {
        let udw = UserDefaultsWrapper<[String]?>(key: .fireproofDomains, defaultValue: nil)
        udw.wrappedValue = ["example.com", "www.secondexample.com"]
        XCTAssertEqual(logins.fireproofDomains.sorted(), ["example.com", "secondexample.com"])
        XCTAssertNil(udw.wrappedValue)
    }

    func testWhenInitWithErrorThenFireproofDomainsWorkCorrectly() {
        struct TestError: Error {}
        store.error = TestError()
        XCTAssertTrue(logins.fireproofDomains.isEmpty)
        store.error = nil
        logins.add(domain: "example.com")
        XCTAssertEqual(logins.fireproofDomains, ["example.com"])
    }

    func testWhenFireproofedDomainsInStoreThenTheyAreLoaded() {
        let udw = UserDefaultsWrapper<[String]?>(key: .fireproofDomains, defaultValue: nil)
        udw.wrappedValue = []
        store.domains = ["example.com": .init(), "secondexample.com": .init()]
        XCTAssertEqual(logins.fireproofDomains.sorted(), ["example.com", "secondexample.com"])
        XCTAssertEqual(udw.wrappedValue, [])
    }

    func testWhenRemovingDomainThenOtherDomainsAreNotRemoved() {
        logins.add(domain: "example.com")
        logins.add(domain: "www.secondexample.com")
        XCTAssertTrue(logins.isFireproof(fireproofDomain: "example.com"))
        XCTAssertTrue(logins.isFireproof(fireproofDomain: "secondexample.com"))

        logins.remove(domain: "secondexample.com")
        XCTAssertTrue(logins.isFireproof(fireproofDomain: "www.example.com"))
        XCTAssertFalse(logins.isFireproof(fireproofDomain: "secondexample.com"))
        XCTAssertFalse(logins.fireproofDomains.isEmpty)
    }

    func testWhenTogglingFireproofDomainThenItIsRemoved() {
        logins.add(domain: "www.example.com")
        XCTAssertFalse(logins.toggle(domain: "example.com"))
        XCTAssertFalse(logins.isFireproof(fireproofDomain: "example.com"))
    }

    func testWhenTogglingNotFireproofedDomainThenItIsAdded() {
        XCTAssertTrue(logins.toggle(domain: "www.example.com"))
        XCTAssertTrue(logins.isFireproof(fireproofDomain: "www.example.com"))
    }

    func testWhenClearAllIsCalledThenAllDomainsAreRemoved() {
        logins.add(domain: "example.com")
        XCTAssertTrue(logins.isFireproof(fireproofDomain: "example.com"))

        logins.clearAll()
        XCTAssertFalse(logins.isFireproof(fireproofDomain: "example.com"))
        XCTAssertTrue(logins.fireproofDomains.isEmpty)
    }

    func testWhenAddingDuplicateDomainsThenSubsequentDomainsAreIgnored() {
        let domain = "example.com"
        logins.add(domain: domain)
        XCTAssertTrue(logins.isFireproof(fireproofDomain: domain))

        logins.add(domain: domain)
        XCTAssertTrue(logins.isFireproof(fireproofDomain: domain))
        XCTAssertEqual(logins.fireproofDomains, [domain])

        logins.remove(domain: domain)
        XCTAssertFalse(logins.isFireproof(fireproofDomain: domain))
        XCTAssertEqual(logins.fireproofDomains, [])
    }

}
