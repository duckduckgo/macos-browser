//
//  ChromiumLoginReaderTests.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class ChromiumLoginReaderTests: XCTestCase {

    private let decryptionKey = "0geUdf5dTuZmIrtd8Omf/Q=="

    func testImport() {
        XCTAssert(true)

        let reader = ChromiumLoginReader(chromiumDataDirectoryPath: databasePath(), processName: "Chrome", decryptionKey: decryptionKey)
        let logins = reader.readLogins()

        if case let .success(logins) = logins, let firstLogin = logins.first {
            XCTAssertEqual(logins.count, 1)

            XCTAssertEqual(firstLogin.url, "news.ycombinator.com")
            XCTAssertEqual(firstLogin.username, "username")
            XCTAssertEqual(firstLogin.password, "password")
        } else {
            XCTFail("Did not get expected number of logins")
        }
    }

    private func databasePath() -> String {
        let bundle = Bundle(for: ChromiumLoginReaderTests.self)
        return bundle.resourcePath!
    }

}
