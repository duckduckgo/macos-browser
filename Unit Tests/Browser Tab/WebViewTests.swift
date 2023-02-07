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

    override func setUp() {
        webView = .init(frame: .zero)
        window.contentView?.addSubview(webView)
    }

    func testInitialZoomLevelAndMagnification() {
        XCTAssertEqual(webView.zoomLevel, 1.0)
        XCTAssertEqual(webView.magnification, 1.0)
    }

    func testThatZoomInIncreasesZoomLevel() {
        let zoomLevel = webView.zoomLevel
        webView.zoomIn()
        XCTAssertGreaterThan(webView.zoomLevel, zoomLevel)
    }

    func testThatZoomOutDecreasesZoomLevel() {
        let zoomLevel = webView.zoomLevel
        webView.zoomOut()
        XCTAssertLessThan(webView.zoomLevel, zoomLevel)
    }

    func testThatZoomLevelIsCappedBetweenMinAndMaxValues() {
        webView.zoomLevel = WebView.maxZoomLevel * 5
        XCTAssertEqual(webView.zoomLevel, WebView.maxZoomLevel)

        webView.zoomLevel = WebView.minZoomLevel * 0.1
        XCTAssertEqual(webView.zoomLevel, WebView.minZoomLevel)
    }

    func testThatWebViewCannotBeZoomedInWhenAtMaxZoomLevel() {
        XCTAssertTrue(webView.canZoomIn)
        XCTAssertTrue(webView.canZoomOut)
        webView.zoomLevel = WebView.maxZoomLevel
        XCTAssertFalse(webView.canZoomIn)
        XCTAssertTrue(webView.canZoomOut)
    }

    func testThatWebViewCannotBeZoomedOutWhenAtMaxZoomLevel() {
        XCTAssertTrue(webView.canZoomIn)
        XCTAssertTrue(webView.canZoomOut)
        webView.zoomLevel = WebView.minZoomLevel
        XCTAssertTrue(webView.canZoomIn)
        XCTAssertFalse(webView.canZoomOut)
    }

    func testThatFreshWebViewInstanceCannotBeZoomedToActualSize() {
        XCTAssertFalse(webView.canZoomToActualSize)
    }

    func testWhenZoomLevelChangesThenWebViewCanBeZoomedToActualSize() {
        webView.zoomLevel = 1.5
        XCTAssertTrue(webView.canZoomToActualSize)
    }

    func testWhenMagnificationChangesThenWebViewCanBeZoomedToActualSize() {
        webView.magnification = 1.5
        XCTAssertTrue(webView.canZoomToActualSize)
    }

    func testWhenZoomLevelAndMagnificationChangeThenWebViewCanBeZoomedToActualSize() {
        webView.zoomLevel = 0.7
        webView.magnification = 1.5
        XCTAssertTrue(webView.canZoomToActualSize)
    }

    func testThatResetZoomLevelResetsZoomAndMagnification() {
        webView.zoomLevel = 0.7
        webView.magnification = 1.5
        webView.resetZoomLevel()
        XCTAssertEqual(webView.zoomLevel, 1.0)
        XCTAssertEqual(webView.magnification, 1.0)
    }
}
