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

class FireproofDomainsTests: XCTestCase {

    override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()
    }

    func testWhenAllowedDomainsContainsFireproofedDomainThenReturnsTrue() {
        let logins = FireproofDomains()
        XCTAssertFalse(logins.isAllowed(fireproofDomain: "example.com"))
        logins.addToAllowed(domain: "example.com")
        XCTAssertTrue(logins.isAllowed(fireproofDomain: "example.com"))
    }

    func testWhenNewThenAllowedDomainsIsEmpty() {
        let logins = FireproofDomains()
        XCTAssertTrue(logins.allowedDomains.isEmpty)
    }

    func testWhenRemovingDomainThenOtherDomainsAreNotRemoved() {
        let logins = FireproofDomains()
        logins.addToAllowed(domain: "example.com")
        logins.addToAllowed(domain: "secondexample.com")
        XCTAssertTrue(logins.isAllowed(fireproofDomain: "example.com"))
        XCTAssertTrue(logins.isAllowed(fireproofDomain: "secondexample.com"))

        logins.remove(domain: "secondexample.com")
        XCTAssertTrue(logins.isAllowed(fireproofDomain: "example.com"))
        XCTAssertFalse(logins.isAllowed(fireproofDomain: "secondexample.com"))
        XCTAssertFalse(logins.allowedDomains.isEmpty)
    }

    func testWhenClearAllIsCalledThenAllDomainsAreRemoved() {
        let logins = FireproofDomains()
        logins.addToAllowed(domain: "example.com")
        XCTAssertTrue(logins.isAllowed(fireproofDomain: "example.com"))

        logins.clearAll()
        XCTAssertFalse(logins.isAllowed(fireproofDomain: "example.com"))
        XCTAssertTrue(logins.allowedDomains.isEmpty)
    }

}
