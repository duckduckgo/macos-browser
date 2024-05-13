//
//  ZoomPopoverViewModelTests.swift
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

final class ZoomPopoverViewModelTests: XCTestCase {

    var tabVM: TabViewModel!
    var zoomPopover: ZoomPopoverViewModel!
    var accessibilityPreferences: AccessibilityPreferences!
    let url = URL(string: "https://app.asana.com/0/1")!
    let hostURL = "https://app.asana.com/"

    @MainActor
    override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()
        let tab = Tab(url: url)
        tabVM = TabViewModel(tab: tab)
        zoomPopover = ZoomPopoverViewModel(tabViewModel: tabVM)
        let window = NSWindow()
        window.contentView = tabVM.tab.webView
    }

    @MainActor
    func test_WhenZoomInFromPopover_ThenWebViewIsZoomedIn() async {
        var increasableDefaultValue = DefaultZoomValue.allCases
        increasableDefaultValue.removeLast()
        let randomZoomLevel = increasableDefaultValue.randomElement()!
        tabVM.tab.webView.zoomLevel = randomZoomLevel

        zoomPopover.zoomIn()

        await MainActor.run {
            XCTAssertEqual(randomZoomLevel.index + 1, tabVM.tab.webView.zoomLevel.index)
            XCTAssertEqual(randomZoomLevel.index + 1, zoomPopover.zoomLevel.index)
        }
    }

    @MainActor
    func test_WhenZoomOutFromPopover_ThenWebViewIsZoomedOut() async {
        var decreasableDefaultValue = DefaultZoomValue.allCases
        decreasableDefaultValue.removeFirst()
        let randomZoomLevel = decreasableDefaultValue.randomElement()!
        tabVM.tab.webView.zoomLevel = randomZoomLevel

        zoomPopover.zoomOut()

        await MainActor.run {
            XCTAssertEqual(randomZoomLevel.index - 1, tabVM.tab.webView.zoomLevel.index)
            XCTAssertEqual(randomZoomLevel.index - 1, zoomPopover.zoomLevel.index)
        }
    }

    @MainActor
    func test_WhenResetZoomFromPopover_ThenWebViewIsReset() async {
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!
        tabVM.tab.webView.defaultZoomValue = .percent100
        tabVM.tab.webView.zoomLevel = randomZoomLevel

        zoomPopover.reset()

        XCTAssertEqual(.percent100, tabVM.tab.webView.zoomLevel)
        await MainActor.run {
            XCTAssertEqual(.percent100, zoomPopover.zoomLevel)
        }
    }

    @MainActor
    func test_WhenZoomValueIsSetInTab_ThenPopoverZoomLevelUpdated() async {
        let expectation = XCTestExpectation()
        zoomPopover = ZoomPopoverViewModel(tabViewModel: tabVM)
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!

        Task {
            tabVM.zoomWasSet(to: randomZoomLevel)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertEqual(zoomPopover.zoomLevel, randomZoomLevel)
    }

}
