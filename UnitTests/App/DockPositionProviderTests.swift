//
//  DockPositionProviderTests.swift
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

class DockPositionProviderTests: XCTestCase {

    var provider: DockPositionProvider!
    var mockBrowserProvider: DefaultBrowserProviderMock!

    override func setUp() {
        super.setUp()
        mockBrowserProvider = DefaultBrowserProviderMock()
        provider = DockPositionProvider(defaultBrowserProvider: mockBrowserProvider)
    }

    override func tearDown() {
        provider = nil
        mockBrowserProvider = nil
        super.tearDown()
    }

    func testWhenAppDefaultBrowser_ThenIndexBasedOnThePrefferedOrder() {
        mockBrowserProvider.isDefault = true
        let currentApps = [DockApp.firefox.url, DockApp.edge.url, DockApp.safari.url]
        let index = provider.newDockIndex(from: currentApps)

        XCTAssertEqual(index, 1, "The new app should be placed based on the order Preference - next To Firefox).")
    }

    func testWhenNotDefaultBrowser_ThenIndexIsNextToDefault() {
        mockBrowserProvider.isDefault = false
        mockBrowserProvider.defaultBrowserURL = DockApp.firefox.url
        let currentApps = [DockApp.safari.url, DockApp.firefox.url, DockApp.arc.url]
        let index = provider.newDockIndex(from: currentApps)

        XCTAssertEqual(index, 2, "The new app should be placed next to default browser.")
    }

    func testWhenNotDefaultBrowserAndNoBrowserFound_ThenIndexIsTheEnd() {
        mockBrowserProvider.isDefault = true
        let currentApps = [URL(string: "file:///Applications/Unknown.app")!, URL(string: "file:///Applications/Unknown2.app")!, URL(string: "file:///Applications/Unknown3.app")!]
        let index = provider.newDockIndex(from: currentApps)

        XCTAssertEqual(index, 3, "The new app should be placed at the end.")
    }
}
