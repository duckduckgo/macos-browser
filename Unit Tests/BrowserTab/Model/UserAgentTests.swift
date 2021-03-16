//
//  UserAgentTests.swift
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

class UserAgentTests: XCTestCase {

    func test_default_user_agent_is_safari() {
        XCTAssertEqual(UserAgent.safari, UserAgent.forDomain("localhost"))
        XCTAssertEqual(UserAgent.safari, UserAgent.forDomain("example.com"))
    }

    func test_when_domain_is_google_docs_then_user_agent_is_chrome() {
        XCTAssertEqual(UserAgent.chrome, UserAgent.forDomain("google.com"))
        XCTAssertEqual(UserAgent.chrome, UserAgent.forDomain("docs.google.com"))
        XCTAssertEqual(UserAgent.chrome, UserAgent.forDomain("spreadsheets.google.com"))
        XCTAssertEqual(UserAgent.chrome, UserAgent.forDomain("a.docs.google.com"))
    }

}
