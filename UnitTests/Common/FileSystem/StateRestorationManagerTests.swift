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

import XCTest
import Combine
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

    @MainActor
    func changeState(_ val1: String?, _ val2: Int?, sync: Bool = false) {
        state.val1 = val1
        state.val2 = val2
        srm.persistState(using: state.encode(with:), sync: sync)
    }

    // MARK: -

    @MainActor
    func testStatePersistence() {
        changeState(nil, nil)
        srm.flush()
        let data = fileStore.storage[testFileName]
        XCTAssertNotNil(data)
        XCTAssertNil(srm.error)
    }

    @MainActor
    func testStatePersistenceError() {
        fileStore.failWithError = CocoaError(.fileWriteNoPermission)
        changeState("val1", 1)
        srm.flush()

        guard case CocoaError(.fileWriteNoPermission) = srm.error as? CocoaError else {
            return XCTFail("Expected fileWriteNoPermission error")
        }
        XCTAssertNil(fileStore.storage[testFileName])
    }

    @MainActor
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

    @MainActor
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

    @MainActor
    func testWhenLastSessionStateIsLoadedThenServiceCanRestoreLastSession() {
        changeState("val1", 1, sync: true)

        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        XCTAssertFalse(srm.canRestoreLastSessionState)

        srm.loadLastSessionState()
        XCTAssertTrue(srm.canRestoreLastSessionState)
    }

    @MainActor
    func testWhenLastSessionStateIsClearedThenLastSessionCannotBeRestored() {
        changeState("val1", 1, sync: true)

        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        srm.loadLastSessionState()
        XCTAssertTrue(srm.canRestoreLastSessionState)

        srm.clearState(sync: true)
        XCTAssertFalse(srm.canRestoreLastSessionState)
    }

    @MainActor
    func testWhenSessionStateIsRestoredItCanBeRestoredAgain() {
        changeState("val1", 1, sync: true)

        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        srm.loadLastSessionState()
        srm.didLoadState()
        XCTAssertTrue(srm.canRestoreLastSessionState)

        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        srm.loadLastSessionState()
        srm.didLoadState()
        XCTAssertTrue(srm.canRestoreLastSessionState)
    }

    @MainActor
    func testWhenSameSessionStateIsRestoredTwiceItBecomesStale() {
        changeState("val1", 1, sync: true)

        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        XCTAssertFalse(srm.isAppStateFileStale)
        srm.loadLastSessionState()
        srm.didLoadState()

        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        XCTAssertFalse(srm.isAppStateFileStale)
        srm.loadLastSessionState()
        srm.didLoadState()
        XCTAssertTrue(srm.isAppStateFileStale)

        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        XCTAssertTrue(srm.isAppStateFileStale)
    }

    @MainActor
    func testWhenLastSessionStateIsLoadedThenChangesToStatePreserveLoadedLastSessionState() {
        changeState("lastSessionValue", 42, sync: true)

        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        srm.loadLastSessionState()

        changeState("currentSessionValue", 7, sync: true)
        XCTAssertNoThrow(try srm.restoreState(using: state.restoreState(from:)))

        XCTAssertEqual(state.val1, "lastSessionValue")
        XCTAssertEqual(state.val2, 42)
    }

    @MainActor
    func testWhenLastSessionStateIsLoadedThenItIsNotDecrypted() {
        let decryptExpectation = expectation(description: "decrypt")
        decryptExpectation.isInverted = true

        fileStore.decryptImpl = { data in
            decryptExpectation.fulfill()
            return data
        }

        changeState("val1", 1, sync: true)
        srm = StatePersistenceService(fileStore: fileStore, fileName: testFileName)
        srm.loadLastSessionState()

        XCTAssertTrue(srm.canRestoreLastSessionState)
        waitForExpectations(timeout: 0.1)
    }

    @MainActor
    func testStatePersistenceThrottlesWrites() {
        fileStore.delay = 0.1 // write operations will sleep for 100ms
        var counter = 0

        let observer = fileStore.publisher(for: \.storage)
            .dropFirst()
            .removeDuplicates()
            .sink { _ in
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

    @MainActor
    func testStatePersistenceSync() {
        fileStore.delay = 0.01 // write operations will sleep for 100ms

        var counter = 0
        let observer = fileStore.publisher(for: \.storage)
            .dropFirst()
            .removeDuplicates()
            .sink { _ in
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

    @MainActor
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
