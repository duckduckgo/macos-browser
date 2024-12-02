//
//  TabBarTests.swift
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

class TabBarTests: UITestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()
    }

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
    }

    func testWhenClickingAddTab_ThenTabsOpen() throws {
//        let app = XCUIApplication()
//
//        let tabbarviewitemElementsQuery = app.windows.collectionViews.otherElements.containing(.group, identifier: "TabBarViewItem")
//        // click on add tab button twice
//        tabbarviewitemElementsQuery.children(matching: .group).element(boundBy: 1).children(matching: .button).element.click()
//        tabbarviewitemElementsQuery.children(matching: .group).element(boundBy: 2).children(matching: .button).element.click()
//
//        let tabs = app.windows.collectionViews.otherElements.containing(.group, identifier: "TabBarViewItem").children(matching: .group)
//            .matching(identifier: "TabBarViewItem")
//
//        XCTAssertEqual(tabs.count, 3)
        _ = XCTSkip("Test needs accessibility identifier debugging before usage")
    }
}
