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
        accessibilityPreferences = AccessibilityPreferences.shared
        zoomPopover = ZoomPopoverViewModel(accessibilityPreferences: accessibilityPreferences, tabViewModel: tabVM)
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
    func test_WhenResetZoomFromPopover_ThenWebViewIsReset() {
        let notificationExpectation = self.expectation(forNotification: AccessibilityPreferences.zoomPerWebsiteUpdated, object: nil, handler: nil)
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!
        tabVM.tab.webView.defaultZoomValue = .percent100
        tabVM.tab.webView.zoomLevel = randomZoomLevel

        zoomPopover.reset()

        XCTAssertEqual(.percent100, tabVM.tab.webView.zoomLevel)
        XCTAssertEqual(.percent100, zoomPopover.zoomLevel)
        wait(for: [notificationExpectation], timeout: 1)
    }

    @MainActor
    func test_WhenZoomValueIsSetInAppearancePreference_ThenPopoverZoomLevelUpdated() async {
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!
        zoomPopover = ZoomPopoverViewModel(accessibilityPreferences: accessibilityPreferences, tabViewModel: tabVM)

        accessibilityPreferences.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)

        await MainActor.run {
            XCTAssertEqual(zoomPopover.zoomLevel, randomZoomLevel)
        }
    }

}
