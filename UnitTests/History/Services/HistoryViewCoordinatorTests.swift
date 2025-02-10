//
//  HistoryViewCoordinatorTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import HistoryView
import PixelKit
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class HistoryViewCoordinatorTests: XCTestCase {
    var coordinator: HistoryViewCoordinator!
    var notificationCenter: NotificationCenter!
    var firePixelCalls: [PixelKitEvent] = []

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        notificationCenter = NotificationCenter()
        firePixelCalls.removeAll()

        coordinator = HistoryViewCoordinator(
            historyCoordinator: MockHistoryGroupingDataSource(),
            notificationCenter: notificationCenter,
            fireDailyPixel: { self.firePixelCalls.append($0) }
        )
    }

    func testWhenHistoryViewAppearsThenPixelIsSent() {
        notificationCenter.post(name: .historyWebViewDidAppear, object: nil)
        XCTAssertEqual(firePixelCalls.count, 1)
    }
}
