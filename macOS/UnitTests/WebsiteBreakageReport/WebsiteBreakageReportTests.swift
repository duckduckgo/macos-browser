//
//  WebsiteBreakageReportTests.swift
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
@testable import Networking
@testable import DuckDuckGo_Privacy_Browser

class WebsiteBreakageReportTests: XCTestCase {

    func testCommonSetOfFields() throws {
        let breakage = WebsiteBreakage(
            category: .contentIsMissing,
            description: nil,
            siteUrlString: "https://example.test/",
            osVersion: "12.3.0",
            upgradedHttps: true,
            tdsETag: "abc123",
            blockedTrackerDomains: [
                "bad.tracker.test",
                "tracking.test"
            ],
            installedSurrogates: [
                "surrogate.domain.test"
            ],
            isGPCEnabled: true,
            ampURL: "https://example.test",
            urlParametersRemoved: false
        )

        let urlRequest = makeURLRequest(with: breakage.requestParameters)

        let url = try XCTUnwrap(urlRequest.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: true))
        let queryItems = try XCTUnwrap(components.percentEncodedQueryItems)

        XCTAssertEqual(url.host, "improving.duckduckgo.com")
        XCTAssertEqual(url.path, "/t/epbf_macos_desktop")

        XCTAssertEqual(queryItems[valueFor: "category"], "content")
        XCTAssertEqual(queryItems[valueFor: "siteUrl"], "https%3A%2F%2Fexample.test%2F")
        XCTAssertEqual(queryItems[valueFor: "upgradedHttps"], "true")
        XCTAssertEqual(queryItems[valueFor: "tds"], "abc123")
        XCTAssertEqual(queryItems[valueFor: "blockedTrackers"], "bad.tracker.test,tracking.test")
        XCTAssertEqual(queryItems[valueFor: "surrogates"], "surrogate.domain.test")
    }

    func testThatNativeAppSpecificFieldsAreReported() throws {
        let breakage = WebsiteBreakage(
            category: .videoOrImagesDidntLoad,
            description: nil,
            siteUrlString: "http://unsafe.example.test/path/to/thing.html",
            osVersion: "12",
            upgradedHttps: false,
            tdsETag: "abc123",
            blockedTrackerDomains: [
                "bad.tracker.test",
                "tracking.test"
            ],
            installedSurrogates: [
                "surrogate.domain.test"
            ],
            isGPCEnabled: true,
            ampURL: "https://example.test",
            urlParametersRemoved: false,
            manufacturer: "IBM"
        )

        let urlRequest = makeURLRequest(with: breakage.requestParameters)

        let url = try XCTUnwrap(urlRequest.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: true))
        let queryItems = try XCTUnwrap(components.percentEncodedQueryItems)

        XCTAssertEqual(url.host, "improving.duckduckgo.com")
        XCTAssertEqual(url.path, "/t/epbf_macos_desktop")

        XCTAssertEqual(queryItems[valueFor: "category"], "images")
        XCTAssertEqual(queryItems[valueFor: "siteUrl"], "http%3A%2F%2Funsafe.example.test%2Fpath%2Fto%2Fthing.html")
        XCTAssertEqual(queryItems[valueFor: "upgradedHttps"], "false")
        XCTAssertEqual(queryItems[valueFor: "tds"], "abc123")
        XCTAssertEqual(queryItems[valueFor: "blockedTrackers"], "bad.tracker.test,tracking.test")
        XCTAssertEqual(queryItems[valueFor: "surrogates"], "surrogate.domain.test")
        XCTAssertEqual(queryItems[valueFor: "manufacturer"], "IBM")
        XCTAssertEqual(queryItems[valueFor: "os"], "12")
        XCTAssertEqual(queryItems[valueFor: "gpc"], "true")
    }

    func makeURLRequest(with parameters: [String: String]) -> URLRequest {
        APIRequest.Headers.setUserAgent("")
        let configuration = APIRequest.Configuration(url: URL.pixelUrl(forPixelNamed: Pixel.Event.brokenSiteReport.name),
                                                     queryParameters: parameters,
                                                     allowedQueryReservedCharacters: WebsiteBreakageSender.allowedQueryReservedCharacters)
        return configuration.request
    }
}

fileprivate extension Array where Element == URLQueryItem {

    subscript(valueFor name: String) -> String? {
        return first(where: { $0.name == name })?.value
    }
}
