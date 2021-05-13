//
//  TrackerRadarManagerTests.swift
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
import CommonCrypto
import TrackerRadarKit
@testable import DuckDuckGo_Privacy_Browser

final class TrackerRadarManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: DefaultConfigurationStorage.shared.fileUrl(for: .trackerRadar))
    }

    func testWhenReloadCalledInitiallyThenDataSetIsEmbedded() {
        XCTAssertEqual(TrackerRadarManager.shared.reload(), .embedded)
    }

    func testFindTrackerByUrl() {
        let tracker = TrackerRadarManager.shared.findTracker(forUrl: "http://googletagmanager.com")
        XCTAssertNotNil(tracker)
        XCTAssertEqual("Google", tracker?.owner?.displayName)
    }

    func testFindEntityByName() {
        let entity = TrackerRadarManager.shared.findEntity(byName: "Google LLC")
        XCTAssertNotNil(entity)
        XCTAssertEqual("Google", entity?.displayName)
    }

    func testFindEntityForHost() {
        let entity = TrackerRadarManager.shared.findEntity(forHost: "www.google.com")
        XCTAssertNotNil(entity)
        XCTAssertEqual("Google", entity?.displayName)
    }

}
