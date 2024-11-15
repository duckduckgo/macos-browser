//
//  DuckPlayerOverlayPixelsTests.swift
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
import PixelKit
@testable import DuckDuckGo_Privacy_Browser

final class PixelFiringMock: PixelFiring {

    static var lastPixelsFired = [PixelKitEventV2]()

    static func tearDown() {
        lastPixelsFired.removeAll()
    }

    func fire(_ event: PixelKitEventV2) {
        Self.lastPixelsFired.append(event)
    }

    func fire(_ event: PixelKitEventV2, frequency: PixelKit.Frequency) {
        Self.lastPixelsFired.append(event)
    }
}

class DuckPlayerOverlayUsagePixelsTests: XCTestCase {

    var duckPlayerOverlayPixels: DuckPlayerOverlayUsagePixels!

    override func setUp() {
        super.setUp()
        PixelFiringMock.tearDown()
        duckPlayerOverlayPixels = DuckPlayerOverlayUsagePixels(pixelFiring: PixelFiringMock(), timeoutInterval: 3.0)
    }

    override func tearDown() {
        PixelFiringMock.tearDown()
        duckPlayerOverlayPixels = nil
        super.tearDown()
    }

    func testRegisterNavigationAppendsURLToHistory() {
        let testURL1 = URL(string: "https://www.youtube.com/watch?v=example1")!
        let testURL2 = URL(string: "https://www.youtube.com/playlist?list=PL-example")!
        let testURL3 = URL(string: "https://www.example.com")!

        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: testURL1, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: testURL2, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: testURL3, duckPlayerMode: .alwaysAsk)

        XCTAssertEqual(duckPlayerOverlayPixels.navigationHistory.count, 3)
        XCTAssertEqual(duckPlayerOverlayPixels.navigationHistory[0], testURL1)
        XCTAssertEqual(duckPlayerOverlayPixels.navigationHistory[1], testURL2)
        XCTAssertEqual(duckPlayerOverlayPixels.navigationHistory[2], testURL3)
    }

    func testBackNavigationTriggersBackPixel() {
        let firstURL = URL(string: "https://www.youtube.com/watch?v=example1")!
        let secondURL = URL(string: "https://www.youtube.com/watch?v=example2")!

        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: firstURL, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: secondURL, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: firstURL, duckPlayerMode: .alwaysAsk)

        XCTAssertEqual(PixelFiringMock.lastPixelsFired.last?.name, GeneralPixel.duckPlayerYouTubeOverlayNavigationBack.name)
    }

    func testReloadNavigationTriggersRefreshPixel() {
        let testURL = URL(string: "https://www.youtube.com/watch?v=XTWWSS")!

        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: testURL, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: testURL, duckPlayerMode: .alwaysAsk)

        XCTAssertEqual(PixelFiringMock.lastPixelsFired.last?.name, GeneralPixel.duckPlayerYouTubeOverlayNavigationRefresh.name)
    }

    func testNavigateWithinYoutubeTriggersWithinYouTubePixel() {
        let videoURL = URL(string: "https://www.youtube.com/watch?v=example1")!
        let playlistURL = URL(string: "https://www.youtube.com/playlist?list=PL-example")!

        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: videoURL, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: playlistURL, duckPlayerMode: .alwaysAsk)

        XCTAssertEqual(PixelFiringMock.lastPixelsFired.last?.name, GeneralPixel.duckPlayerYouTubeNavigationWithinYouTube.name)
    }

    func testNavigateOutsideYoutubeTriggersOutsideYouTubePixel() {
        let youtubeURL = URL(string: "https://www.youtube.com/watch?v=example1")!
        let outsideURL = URL(string: "https://www.example.com")!

        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: youtubeURL, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: outsideURL, duckPlayerMode: .alwaysAsk)

        XCTAssertEqual(PixelFiringMock.lastPixelsFired.last?.name, GeneralPixel.duckPlayerYouTubeOverlayNavigationOutsideYoutube.name)
    }

    func testBackNavigationDoesNotTriggerWithinOrOutsideYouTubePixel() {
        let firstURL = URL(string: "https://www.youtube.com/watch?v=example1")!
        let secondURL = URL(string: "https://www.youtube.com/watch?v=example2")!
        let backURL = URL(string: "https://www.youtube.com/watch?v=example1")!

        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: firstURL, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: secondURL, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: backURL, duckPlayerMode: .alwaysAsk)

        XCTAssertNotEqual(PixelFiringMock.lastPixelsFired.last?.name, GeneralPixel.duckPlayerYouTubeNavigationWithinYouTube.name)
        XCTAssertNotEqual(PixelFiringMock.lastPixelsFired.last?.name, GeneralPixel.duckPlayerYouTubeOverlayNavigationOutsideYoutube.name)
    }

    func testReloadNavigationDoesNotTriggerWithinOrOutsideYouTubePixel() {
        let testURL = URL(string: "https://www.youtube.com/watch?v=example")!

        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: testURL, duckPlayerMode: .alwaysAsk)
        duckPlayerOverlayPixels.handleNavigationAndFirePixels(url: testURL, duckPlayerMode: .alwaysAsk)

        XCTAssertNotEqual(PixelFiringMock.lastPixelsFired.last?.name, GeneralPixel.duckPlayerYouTubeNavigationWithinYouTube.name)
        XCTAssertNotEqual(PixelFiringMock.lastPixelsFired.last?.name, GeneralPixel.duckPlayerYouTubeOverlayNavigationOutsideYoutube.name)
    }
}
