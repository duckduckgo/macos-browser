//
//  ZoomPopoverViewModelTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
    var appearancePreferences: AppearancePreferences!

    @MainActor
    override func setUp() {
        UserDefaultsWrapper<Any>.clearAll()
        tabVM = TabViewModel(tab: Tab())
        appearancePreferences = AppearancePreferences()
        zoomPopover = ZoomPopoverViewModel(appearancePreferences: appearancePreferences, tabViewModel: tabVM)
        let window = NSWindow()
        window.contentView = tabVM.tab.webView
    }

    @MainActor
    func testWhenZoomInFromPopoverThenWebViewIsZoomedIn() {
        var increasableDefaultValue = DefaultZoomValue.allCases
        increasableDefaultValue.removeLast()
        let randomZoomLevel = increasableDefaultValue.randomElement()!
        tabVM.tab.webView.zoomLevel = randomZoomLevel

        zoomPopover.zoomIn()

        XCTAssertEqual(randomZoomLevel.index + 1, tabVM.tab.webView.zoomLevel.index)
    }

    @MainActor
    func testWhenZoomOutFromPopoverThenWebViewIsZoomedOut() {
        var decreasableDefaultValue = DefaultZoomValue.allCases
        decreasableDefaultValue.removeFirst()
        let randomZoomLevel = decreasableDefaultValue.randomElement()!
        tabVM.tab.webView.zoomLevel = randomZoomLevel

        zoomPopover.zoomOut()

        XCTAssertEqual(randomZoomLevel.index - 1, tabVM.tab.webView.zoomLevel.index)
    }

    @MainActor
    func testWhenResetZoomFromPopoverThenWebViewIsReset() {
        var decreasableDefaultValue = DefaultZoomValue.allCases
        decreasableDefaultValue.removeFirst()
        let randomZoomLevel = decreasableDefaultValue.randomElement()!
        tabVM.tab.webView.zoomLevel = randomZoomLevel

        zoomPopover.reset()

        XCTAssertEqual(appearancePreferences.defaultPageZoom, tabVM.tab.webView.zoomLevel)
    }

    @MainActor
    func testWhenZoomValueIsSetInAppearancePreferenceThenPopoverZoomLevelUpdated() {
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!
        let tab = Tab(url: url)
        let tabVM = TabViewModel(tab: tab, appearancePreferences: appearancePreferences)
        zoomPopover = ZoomPopoverViewModel(appearancePreferences: appearancePreferences, tabViewModel: tabVM)
        appearancePreferences.updateZoomPerWebsite(zoomLevel: randomZoomLevel, website: hostURL)

        XCTAssertEqual(zoomPopover.zoomLevel, randomZoomLevel)
    }

}
