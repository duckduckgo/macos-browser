//
//  BinaryOwnershipCheckerTests.swift
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

import BrowserServicesKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class BinaryOwnershipCheckerTests: XCTestCase {

    func testWhenUserIsOwner_ThenIsCurrentUserOwnerReturnsTrue() {
        let mockFileManager = MockFileManager()
        mockFileManager.attributes = [
            .ownerAccountID: NSNumber(value: getuid())
        ]
        let checker = BinaryOwnershipChecker(fileManager: mockFileManager)
        let isOwner = checker.isCurrentUserOwner()

        XCTAssertTrue(isOwner, "Expected the current user to be identified as the owner.")
    }

    func testWhenUserIsNotOwner_ThenIsCurrentUserOwnerReturnsFalse() {
        let mockFileManager = MockFileManager()
        mockFileManager.attributes = [
            .ownerAccountID: NSNumber(value: getuid() + 1) // Simulate a different user
        ]
        let checker = BinaryOwnershipChecker(fileManager: mockFileManager)
        let isOwner = checker.isCurrentUserOwner()

        XCTAssertFalse(isOwner, "Expected the current user not to be identified as the owner.")
    }

    func testWhenFileManagerThrowsError_ThenIsCurrentUserOwnerReturnsFalse() {
        let mockFileManager = MockFileManager()
        mockFileManager.shouldThrowError = true
        let checker = BinaryOwnershipChecker(fileManager: mockFileManager)
        let isOwner = checker.isCurrentUserOwner()

        XCTAssertFalse(isOwner, "Expected the ownership check to fail and return false when an error occurs.")
    }

    func testWhenOwnershipIsCheckedMultipleTimes_ThenResultIsCached() {
        let mockFileManager = MockFileManager()
        mockFileManager.attributes = [
            .ownerAccountID: NSNumber(value: getuid())
        ]
        let checker = BinaryOwnershipChecker(fileManager: mockFileManager)
        let isOwnerFirstCheck = checker.isCurrentUserOwner()

        mockFileManager.attributes = [
            .ownerAccountID: NSNumber(value: getuid() + 1)
        ]
        let isOwnerSecondCheck = checker.isCurrentUserOwner()

        XCTAssertTrue(isOwnerFirstCheck, "Expected the current user to be identified as the owner on first check.")
        XCTAssertTrue(isOwnerSecondCheck, "Expected the cached result to be used, so the second check should return the same result as the first.")
    }
}

// Mock FileManager to simulate different file attributes and errors
class MockFileManager: FileManager {

    var attributes: [FileAttributeKey: Any]?
    var shouldThrowError = false

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        if shouldThrowError {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: nil)
        }
        return attributes ?? [:]
    }
}
