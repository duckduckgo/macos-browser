//
//  WebViewTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class WebViewTests: XCTestCase {

    typealias WebView = DuckDuckGo_Privacy_Browser.WebView

    let window = NSWindow()
    var webView: WebView!
    var capturingZoomLevelDelegate: CapturingZoomLevelDelegate!

    override func setUp() {
        webView = .init(frame: .zero)
        window.contentView?.addSubview(webView)
        capturingZoomLevelDelegate = CapturingZoomLevelDelegate()
    }

    override func tearDown() {
        webView = nil
        capturingZoomLevelDelegate = nil
    }

    func testInitialZoomLevelAndMagnification() {
        XCTAssertEqual(webView.zoomLevel, DefaultZoomValue.percent100)
        XCTAssertEqual(webView.magnification, DefaultZoomValue.percent100.rawValue)
    }

    func testThatZoomInIncreasesZoomLevel() {
        let zoomLevel = webView.zoomLevel
        webView.zoomIn()
        XCTAssertGreaterThan(webView.zoomLevel.rawValue, zoomLevel.rawValue)
    }

    func testThatZoomIncreaesUsingDefaultSteps() {
        var increasableDefaultValue = DefaultZoomValue.allCases
        increasableDefaultValue.removeLast()
        let randomZoomLevel = increasableDefaultValue.randomElement()!
        webView.zoomLevel = randomZoomLevel

        webView.zoomIn()

        XCTAssertEqual(randomZoomLevel.index + 1, webView.zoomLevel.index)
    }

    func testThatZoomDecreasesUsingDefaultSteps() {
        var decreasableDefaultValue = DefaultZoomValue.allCases
        decreasableDefaultValue.removeFirst()
        let randomZoomLevel = decreasableDefaultValue.randomElement()!
        webView.zoomLevel = randomZoomLevel

        webView.zoomOut()

        XCTAssertEqual(randomZoomLevel.index - 1, webView.zoomLevel.index)
    }

    func testThatItIsNotPossibleToZoomInFromLastDefaultValue() {
        webView.zoomLevel = DefaultZoomValue.allCases.last!

        webView.zoomIn()

        XCTAssertEqual(webView.zoomLevel, DefaultZoomValue.allCases.last!)
    }

    func testThatItIsNotPossibleToZoomOutFromFirstDefaultValue() {
        webView.zoomLevel = DefaultZoomValue.allCases.first!

        webView.zoomOut()

        XCTAssertEqual(webView.zoomLevel, DefaultZoomValue.allCases.first!)
    }

    func testThatZoomOutDecreasesZoomLevel() {
        let zoomLevel = webView.zoomLevel
        webView.zoomOut()
        XCTAssertLessThan(webView.zoomLevel.rawValue, zoomLevel.rawValue)
    }

    func testThatWebViewCannotBeZoomedInWhenAtMaxZoomLevel() {
        XCTAssertTrue(webView.canZoomIn)
        XCTAssertTrue(webView.canZoomOut)
        webView.zoomLevel = DefaultZoomValue.allCases[ DefaultZoomValue.allCases.count - 1]
        XCTAssertFalse(webView.canZoomIn)
        XCTAssertTrue(webView.canZoomOut)
    }

    func testThatWebViewCannotBeZoomedOutWhenAtMaxZoomLevel() {
        XCTAssertTrue(webView.canZoomIn)
        XCTAssertTrue(webView.canZoomOut)
        webView.zoomLevel = DefaultZoomValue.allCases[0]
        XCTAssertTrue(webView.canZoomIn)
        XCTAssertFalse(webView.canZoomOut)
    }

    func testThatFreshWebViewInstanceCannotBeZoomedToActualSize() {
        XCTAssertFalse(webView.canZoomToActualSize)
    }

    func testThatFreshWebViewInstanceCannotResetMagnification() {
        XCTAssertFalse(webView.canResetMagnification)
    }

    func testWhenZoomLevelChangesThenWebViewCanBeZoomedToActualSize() {
        webView.zoomLevel = .percent150
        XCTAssertTrue(webView.canZoomToActualSize)
    }

    func testWhenMagnificationLevelChangesThenWebViewCanResetMagnification() {
        webView.magnification = 2.0
        XCTAssertTrue(webView.canResetMagnification)
    }

    func testWhenMagnificationChangesThenWebViewCanBeZoomedToActualSize() {
        webView.zoomLevel = DefaultZoomValue.percent150
        XCTAssertTrue(webView.canZoomToActualSize)
    }

    @MainActor
    func testThatResetZoomLevelResetsZoom() {
        let tabVM = TabViewModel(tab: Tab())
        let randomZoomLevel = DefaultZoomValue.percent300
        // Select Default zoom
        AccessibilityPreferences.shared.defaultPageZoom = randomZoomLevel

        // Zooming out
        tabVM.tab.webView.zoomOut()
        tabVM.tab.webView.zoomOut()
        tabVM.tab.webView.zoomOut()

        // Reset
        tabVM.tab.webView.resetZoomLevel()

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)

        // Set new default zoom
        AccessibilityPreferences.shared.defaultPageZoom = .percent75
        XCTAssertEqual(tabVM.tab.webView.zoomLevel, .percent75)
    }

    @MainActor
    func testThatResetZoomLevelResetsMagnification() {
        let tabVM = TabViewModel(tab: Tab())

        // Set MAgnification
        tabVM.tab.webView.magnification = 3.0

        // Reset
        tabVM.tab.webView.resetZoomLevel()

        XCTAssertEqual(tabVM.tab.webView.magnification, 1)
    }

    func test_WhenZoomingIn_ThenZoomDelegateZoomWasSetIsCalled() {
        // GIVEN
        var increasableDefaultValue = DefaultZoomValue.allCases
        increasableDefaultValue.removeLast()
        let randomZoomLevel = increasableDefaultValue.randomElement()!
        webView.zoomLevel = randomZoomLevel
        webView.zoomLevelDelegate = capturingZoomLevelDelegate

        // WHEN
        webView.zoomIn()

        // THEN
        XCTAssertEqual(capturingZoomLevelDelegate.setLevel, DefaultZoomValue.allCases[randomZoomLevel.index + 1])
    }

    func test_WhenZoomingOut_ThenZoomDelegateZoomWasSetIsCalled() {
        // GIVEN
        var decreasableDefaultValue = DefaultZoomValue.allCases
        decreasableDefaultValue.removeFirst()
        let randomZoomLevel = decreasableDefaultValue.randomElement()!
        webView.zoomLevel = randomZoomLevel
        webView.zoomLevelDelegate = capturingZoomLevelDelegate

        // WHEN
        webView.zoomOut()

        // THEN
        XCTAssertEqual(capturingZoomLevelDelegate.setLevel, DefaultZoomValue.allCases[randomZoomLevel.index - 1])
    }

    func testWhenResettingZoomThenZoomDelegateZoomWasSetIsCalled() {
        // GIVEN
        let randomZoomLevel = DefaultZoomValue.allCases.randomElement()!
        webView.zoomLevel = randomZoomLevel
        webView.zoomLevelDelegate = capturingZoomLevelDelegate

        // WHEN
        webView.resetZoomLevel()

        // THEN
        XCTAssertEqual(capturingZoomLevelDelegate.setLevel, .percent100)
    }
}

class CapturingZoomLevelDelegate: WebViewZoomLevelDelegate {
     var setLevel: DefaultZoomValue?

     func zoomWasSet(to level: DefaultZoomValue) {
         setLevel = level
     }
 }
