//
//  PrivatePlayerTests.swift
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

final class PrivatePlayerTests: XCTestCase {

    func testYoutubeVideoParamsFromPrivatePlayerURL() {
        let params = "privateplayer:n5-_Nncm82s?t=23s".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "n5-_Nncm82s")
        XCTAssertEqual(params?.timestamp, "23s")
    }

    func testYoutubeVideoParamsFromYouTubeURL() {
        let params = "https://www.youtube.com/watch?v=n5-_Nncm82s&t=23s".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "n5-_Nncm82s")
        XCTAssertEqual(params?.timestamp, "23s")
    }

    func testYoutubeVideoParamsFromYouTubeNocookieURL() {
        let params = "https://www.youtube-nocookie.com/embed/n5-_Nncm82s?t=23s".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "n5-_Nncm82s")
        XCTAssertEqual(params?.timestamp, "23s")
    }

    func testPrivatePlayerURL() {
        XCTAssertEqual(URL.privatePlayer("n5-_Nncm82s", timestamp: "23s"), "privateplayer:n5-_Nncm82s?t=23s".url)
    }
}
