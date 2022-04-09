//
//  StateRestorationManagerTests.swift
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

import Combine
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class StateRestorationManagerTests: XCTestCase {
    private var fileStore: FileStoreMock!
    private let testFileName = "TestFile"
    private var state: SavedStateMock!
    private var srm: StatePersistenceService!

    override func setUp() {
        fileStore = FileStoreMock()
        state = SavedStateMock()
        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
    }

    override func tearDown() {
        srm = nil
    }

    func changeState(_ val1: String?, _ val2: Int?, sync: Bool = false) {
        state.val1 = val1
        state.val2 = val2
        srm.persistState(using: state.encode(with:), sync: sync)
    }

    // MARK: -

    func testStatePersistence() {
        changeState(nil, nil)
        srm.flush()
        let data = fileStore.storage[testFileName]
        XCTAssertNotNil(data)
        XCTAssertNil(srm.error)
    }

    func testStatePersistenceError() {
        fileStore.failWithError = CocoaError(.fileWriteNoPermission)
        changeState("val1", 1)
        srm.flush()

        guard case CocoaError(.fileWriteNoPermission) = srm.error as? CocoaError else {
            return XCTFail("Expected fileWriteNoPermission error")
        }
        XCTAssertNil(fileStore.storage[testFileName])
    }

    func testNoPersistentStateAtStartup() {
        srm.flush()

        XCTAssertThrowsError(try srm.restoreState(using: state.restoreState(from:)), NSCocoaErrorDomain) {
            guard ($0 as? CocoaError)?.code == .fileReadNoSuchFile else {
                return XCTFail("Unexpected \($0), expected \(CocoaError(.fileReadNoSuchFile))")
            }
        }
        XCTAssertNil(state.val1)
        XCTAssertNil(state.val2)
    }

    func testStatePersistenceAndRestoration() {
        changeState("val1", 1)
        changeState("val2", 2)
        changeState("val3", 3)
        srm.flush()

        let state = SavedStateMock()
        XCTAssertNoThrow(try srm.restoreState(using: state.restoreState(from:)))
        XCTAssertEqual(state.val1, "val3")
        XCTAssertEqual(state.val2, 3)
    }

    func testStatePersistenceThrottlesWrites() {
        fileStore.delay = 0.1 // write operations will sleep for 100ms
        var counter = 0
        let observer = fileStore.observe(\.storage) { _, _ in
            counter += 1
        }

        changeState("val1", 1)
        changeState("val2", 2)
        changeState("val3", 3)
        changeState("val4", 4)
        changeState("val5", 5)

        srm.flush()
        withExtendedLifetime(observer) {
            XCTAssertLessThanOrEqual(counter, 2)
        }
    }

    func testStatePersistenceSync() {
        fileStore.delay = 0.01 // write operations will sleep for 100ms

        var counter = 0
        let observer = fileStore.observe(\.storage) { _, _ in
            counter += 1
        }

        changeState("val1", 1, sync: true)
        changeState("val2", 2, sync: true)
        changeState("val3", 3, sync: true)
        changeState("val4", 4, sync: true)
        changeState("val5", 5, sync: true)

        withExtendedLifetime(observer) {
            XCTAssertLessThanOrEqual(counter, 5)
        }

        let state = SavedStateMock()
        XCTAssertNoThrow(try srm.restoreState(using: state.restoreState(from:)))
        XCTAssertEqual(state.val1, "val5")
        XCTAssertEqual(state.val2, 5)
    }

    func testStatePersistenceClear() {
        changeState("val1", 1)
        changeState("val2", 2)
        changeState("val3", 3)
        changeState("val4", 4)
        changeState("val5", 5)

        srm.clearState()
        srm.flush()

        XCTAssertThrowsError(try srm.restoreState(using: state.restoreState(from:)), NSCocoaErrorDomain) {
            guard ($0 as? CocoaError)?.code == .fileReadNoSuchFile else {
                return XCTFail("Unexpected \($0), expected \(CocoaError(.fileReadNoSuchFile))")
            }
        }
    }
}

@objc(SavedStateMock)
private class SavedStateMock: NSObject {
    private enum NSSecureCodingKeys {
        static let key1 = "key1"
        static let key2 = "key2"
    }

    static var supportsSecureCoding = true

    var val1: String?
    var val2: Int?

    override init() {
    }

    func encode(with coder: NSCoder) {
        val1.map(coder.encode(forKey: NSSecureCodingKeys.key1))
        val2.map(coder.encode(forKey: NSSecureCodingKeys.key2))
    }

    func restoreState(from coder: NSCoder) throws {
        val1 = coder.decodeIfPresent(at: NSSecureCodingKeys.key1)
        val2 = coder.decodeIfPresent(at: NSSecureCodingKeys.key2)
    }
}
