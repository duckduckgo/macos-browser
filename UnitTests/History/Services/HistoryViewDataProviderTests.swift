//
//  HistoryViewDataProviderTests.swift
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

import History
import HistoryView
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class MockHistoryViewDateFormatter: HistoryViewDateFormatting {
    func weekDay(for date: Date) -> String {
        "Today"
    }

    func time(for date: Date) -> String {
        "10:08"
    }
}

final class HistoryViewDataProviderTests: XCTestCase {
    var provider: HistoryViewDataProvider!

    override func setUp() {
        provider = HistoryViewDataProvider(
            historyGroupingDataSource: MockHistoryGroupingDataSource(),
            dateFormatter: MockHistoryViewDateFormatter()
        )
    }
}
