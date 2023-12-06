//
//  SetExtensionTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import XCTest
import Combine
import Common
@testable import DuckDuckGo_Privacy_Browser

class SetExtensionTests: XCTestCase {

    func testConvertedToETLDPlus1() {
        let domains: Set<String> = ["www.google.com", "mail.yahoo.co.uk", "invalid"]
        let result = domains.convertedToETLDPlus1(tld: ContentBlocking.shared.tld)
        let expected: Set<String> = ["google.com", "yahoo.co.uk"]
        XCTAssertEqual(result, expected, "The converted set should only contain valid eTLD+1 domains.")
    }

}
