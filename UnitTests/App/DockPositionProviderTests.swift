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

    func testWhenNotDefaultBrowser_ThenIndexIsNextToDefault() {
        mockBrowserProvider.isDefault = false
        mockBrowserProvider.defaultBrowserURL = URL(string: "file:///Applications/Firefox.app/")!
        let currentApps = [URL(string: "file:///Applications/Safari.app/")!, URL(string: "file:///Applications/Firefox.app/")!, URL(string: "file:///Applications/Arc.app/")!]
        let index = provider.newDockIndex(from: currentApps)

        XCTAssertEqual(index, 2, "The new app should be placed next to default browser.")
    }

}
