//
//  ProgressExtensionTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class ProgressExtensionTests: XCTestCase {

    func testWhenExecuteWithPublishedProgressThenShouldReceiveProgressUpdates() throws {
        // GIVEN
        let expectation = self.expectation(description: #function)
        let testData = try XCTUnwrap("test".data(using: .utf8))
        let fileManager = FileManager.default
        let url = fileManager.temporaryDirectory.appendingPathComponent("Document.txt")
        var didReceiveProgressUpdates = false

        Progress.addSubscriber(forFileURL: url) { progress in
            didReceiveProgressUpdates = true
            expectation.fulfill()
            return {}
        }

        XCTAssertFalse(didReceiveProgressUpdates)

        // WHEN
        try Progress.withPublishedProgress(url: url) {
            try testData.write(to: url)
        }

        // THEN
        waitForExpectations(timeout: 0.5)
        XCTAssertTrue(didReceiveProgressUpdates)
    }

}
