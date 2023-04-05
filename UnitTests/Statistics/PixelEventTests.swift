//
//  PixelEventTests.swift
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
@testable import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

final class PixelEventTests: XCTestCase {

    func testWhenFormattingJSPixel_ThenJSPixelIncludesPixelName() throws {
        let pixel = AutofillUserScript.JSPixel(pixelName: "pixel_name", pixelParameters: nil)
        let event = Pixel.Event.jsPixel(pixel)

        XCTAssertEqual(event.name, "m_mac_pixel_name")
    }

    func testWhenFormattingDuckPlayerJSPixel_ThenJSPixelIncludesCorrectFormatting() throws {
        typealias JSPixel = YoutubeOverlayUserScript.JSPixel;

        let pixels = [
            Pixel.Event.duckPlayerJSPixel(JSPixel.overlay),
            Pixel.Event.duckPlayerJSPixel(JSPixel.playUse),
            Pixel.Event.duckPlayerJSPixel(JSPixel.playDoNotUse),
        ]

        let expected = [
            "duck_player.mac.overlay",
            "duck_player.mac.play.use",
            "duck_player.mac.play.do_not_use"
        ]

        XCTAssertEqual(pixels[0].name, expected[0])
        XCTAssertEqual(pixels[1].name, expected[1])
        XCTAssertEqual(pixels[2].name, expected[2])
    }
}
