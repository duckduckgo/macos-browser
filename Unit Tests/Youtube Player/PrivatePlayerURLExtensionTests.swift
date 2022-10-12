//
//  PrivatePlayerURLExtensionTests.swift
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

final class PrivatePlayerURLExtensionTests: XCTestCase {

    func testIsPrivatePlayerScheme() {
        XCTAssertTrue("duck:player/abcdef12345".url!.isPrivatePlayerScheme)
        XCTAssertTrue("duck://player/abcdef12345".url!.isPrivatePlayerScheme)
        XCTAssertTrue("duck://player/abcdef".url!.isPrivatePlayerScheme)
        XCTAssertTrue("duck://player/12345".url!.isPrivatePlayerScheme)
        XCTAssertFalse("http://privateplayer/abcdef12345".url!.isPrivatePlayerScheme)
        XCTAssertFalse("https://www.youtube.com/watch?v=abcdef12345".url!.isPrivatePlayerScheme)
        XCTAssertFalse("https://www.youtube-nocookie.com/embed/abcdef12345".url!.isPrivatePlayerScheme)
    }

    func testIsPrivatePlayer() {
        XCTAssertTrue("https://www.youtube-nocookie.com/embed/abcdef12345".url!.isPrivatePlayer)
        XCTAssertTrue("https://www.youtube-nocookie.com/embed/abcdef12345?t=23s".url!.isPrivatePlayer)

        XCTAssertFalse("https://www.youtube-nocookie.com/embed".url!.isPrivatePlayer)
        XCTAssertFalse("https://www.youtube-nocookie.com/embed?t=23s".url!.isPrivatePlayer)

        XCTAssertFalse("duck://player/abcdef12345".url!.isPrivatePlayer)
        XCTAssertFalse("https://www.youtube.com/watch?v=abcdef12345".url!.isPrivatePlayer)
        XCTAssertFalse("https://duckduckgo.com".url!.isPrivatePlayer)
    }

    func testIsYoutubePlaylist() {
        XCTAssertTrue("https://www.youtube.com/watch?v=abcdef12345&list=abcdefgh12345678".url!.isYoutubePlaylist)
        XCTAssertTrue("https://www.youtube.com/watch?list=abcdefgh12345678&v=abcdef12345".url!.isYoutubePlaylist)

        XCTAssertFalse("https://duckduckgo.com/watch?v=abcdef12345&list=abcdefgh12345678".url!.isYoutubePlaylist)
        XCTAssertFalse("https://www.youtube.com/watch?list=abcdefgh12345678".url!.isYoutubePlaylist)
        XCTAssertFalse("https://www.youtube.com/watch?v=abcdef12345&list=abcdefgh12345678&index=1".url!.isYoutubePlaylist)
    }

    func testIsYoutubeVideo() {
        XCTAssertTrue("https://www.youtube.com/watch?v=abcdef12345".url!.isYoutubeVideo)
        XCTAssertTrue("https://www.youtube.com/watch?v=abcdef12345&list=abcdefgh12345678&index=1".url!.isYoutubeVideo)
        XCTAssertTrue("https://www.youtube.com/watch?v=abcdef12345&t=5m".url!.isYoutubeVideo)

        XCTAssertFalse("https://www.youtube.com/watch?v=abcdef12345&list=abcdefgh12345678".url!.isYoutubeVideo)
        XCTAssertFalse("https://duckduckgo.com/watch?v=abcdef12345".url!.isYoutubeVideo)
    }

    func testYoutubeVideoParamsFromPrivatePlayerURL() {
        let params = "duck://player/abcdef12345".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "abcdef12345")
        XCTAssertEqual(params?.timestamp, nil)

        let paramsWithTimestamp = "duck://player/abcdef12345?t=23s".url!.youtubeVideoParams
        XCTAssertEqual(paramsWithTimestamp?.videoID, "abcdef12345")
        XCTAssertEqual(paramsWithTimestamp?.timestamp, "23s")
    }

    func testYoutubeVideoParamsFromYoutubeURL() {
        let params = "https://www.youtube.com/watch?v=abcdef12345".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "abcdef12345")
        XCTAssertEqual(params?.timestamp, nil)

        let paramsWithTimestamp = "https://www.youtube.com/watch?v=abcdef12345&t=23s".url!.youtubeVideoParams
        XCTAssertEqual(paramsWithTimestamp?.videoID, "abcdef12345")
        XCTAssertEqual(paramsWithTimestamp?.timestamp, "23s")

        let paramsWithTimestampWithoutUnits = "https://www.youtube.com/watch?t=102&v=abcdef12345&feature=youtu.be".url!.youtubeVideoParams
        XCTAssertEqual(paramsWithTimestampWithoutUnits?.videoID, "abcdef12345")
        XCTAssertEqual(paramsWithTimestampWithoutUnits?.timestamp, "102")
    }

    func testYoutubeVideoParamsFromYoutubeNocookieURL() {
        let params = "https://www.youtube-nocookie.com/embed/abcdef12345".url!.youtubeVideoParams
        XCTAssertEqual(params?.videoID, "abcdef12345")
        XCTAssertEqual(params?.timestamp, nil)

        let paramsWithTimestamp = "https://www.youtube-nocookie.com/embed/abcdef12345?t=23s".url!.youtubeVideoParams
        XCTAssertEqual(paramsWithTimestamp?.videoID, "abcdef12345")
        XCTAssertEqual(paramsWithTimestamp?.timestamp, "23s")
    }

    func testYoutubeVideoID() {
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: nil).youtubeVideoID, "abcdef12345")
        XCTAssertEqual(URL.youtube("abcd<br>ef12345", timestamp: nil).youtubeVideoID, "abcdbref12345")

        XCTAssertNil("https://duck.com".url?.youtubeVideoID)
    }

    func testPrivatePlayerURLTimestampValidation() {
        XCTAssertEqual(URL.privatePlayer("abcdef12345", timestamp: nil).absoluteString, "duck://player/abcdef12345")
        XCTAssertEqual(URL.privatePlayer("abcdef12345", timestamp: "23s").absoluteString, "duck://player/abcdef12345?t=23s")
        XCTAssertEqual(URL.privatePlayer("abcdef12345", timestamp: "5m5s").absoluteString, "duck://player/abcdef12345?t=5m5s")
        XCTAssertEqual(URL.privatePlayer("abcdef12345", timestamp: "12h400m100s").absoluteString, "duck://player/abcdef12345?t=12h400m100s")
        XCTAssertEqual(URL.privatePlayer("abcdef12345", timestamp: "12h2s2h").absoluteString, "duck://player/abcdef12345?t=12h2s2h")
        XCTAssertEqual(URL.privatePlayer("abcdef12345", timestamp: "5m5m5m").absoluteString, "duck://player/abcdef12345?t=5m5m5m")

        XCTAssertEqual(URL.privatePlayer("abcdef12345", timestamp: "5").absoluteString, "duck://player/abcdef12345?t=5")
        XCTAssertEqual(URL.privatePlayer("abcdef12345", timestamp: "10d").absoluteString, "duck://player/abcdef12345")
    }

    func testYoutubeURLTimestampValidation() {
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: nil).absoluteString, "https://www.youtube.com/watch?v=abcdef12345")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "23s").absoluteString, "https://www.youtube.com/watch?v=abcdef12345&t=23s")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "5m5s").absoluteString, "https://www.youtube.com/watch?v=abcdef12345&t=5m5s")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "12h400m100s").absoluteString, "https://www.youtube.com/watch?v=abcdef12345&t=12h400m100s")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "12h2s2h").absoluteString, "https://www.youtube.com/watch?v=abcdef12345&t=12h2s2h")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "5m5m5m").absoluteString, "https://www.youtube.com/watch?v=abcdef12345&t=5m5m5m")

        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "5").absoluteString, "https://www.youtube.com/watch?v=abcdef12345&t=5")
        XCTAssertEqual(URL.youtube("abcdef12345", timestamp: "10d").absoluteString, "https://www.youtube.com/watch?v=abcdef12345")
    }

    func testYoutubeNoCookieURLTimestampValidation() {
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: nil).absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "23s").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=23s")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "5m5s").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=5m5s")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "12h400m100s").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=12h400m100s")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "12h2s2h").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=12h2s2h")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "5m5m5m").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=5m5m5m")

        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "5").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345?t=5")
        XCTAssertEqual(URL.youtubeNoCookie("abcdef12345", timestamp: "10d").absoluteString, "https://www.youtube-nocookie.com/embed/abcdef12345")
    }
}
