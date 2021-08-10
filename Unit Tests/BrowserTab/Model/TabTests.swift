//
//  TabTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

final class TabTests: XCTestCase {

    func testWhenSettingURLThenTabTypeChangesToStandard() {
        let tab = Tab(content: .preferences)
        XCTAssertEqual(tab.content, .preferences)

        tab.url = URL.duckDuckGo
        XCTAssertEqual(tab.content, .url(.duckDuckGo))
    }

    // MARK: - Equality

    func testWhenTabsAreIdenticalThenTheyAreEqual() {
        let tab = Tab()
        let tab2 = tab

        XCTAssert(tab == tab2)
    }

    func testWhenTabsArentIdenticalThenTheyArentEqual() {
        let tab = Tab()
        tab.url = URL.duckDuckGo
        let tab2 = Tab()
        tab2.url = URL.duckDuckGo

        XCTAssert(tab != tab2)
    }
    
}

extension Tab {
    var url: URL? {
        get {
            content.url
        }
        set {
            content = newValue.map(TabContent.url) ?? .homepage
        }
    }
}
