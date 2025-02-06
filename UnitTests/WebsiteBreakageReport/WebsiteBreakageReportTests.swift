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

import PrivacyDashboard
import XCTest
import PixelKit
import PixelKitTestingUtilities
@testable import DuckDuckGo_Privacy_Browser
@testable import Networking

class WebsiteBreakageReportTests: XCTestCase {

    func testReportBrokenSitePixel() {
        fire(NonStandardEvent(NonStandardPixel.brokenSiteReport),
             frequency: .standard,
             and: .expect(pixelName: "epbf_macos_desktop"),
             file: #filePath,
             line: #line)
    }

    func testReportBrokenSiteShownPixel() {
        fire(NonStandardEvent(NonStandardPixel.brokenSiteReportShown),
             frequency: .standard,
             and: .expect(pixelName: "m_report-broken-site_shown"),
             file: #filePath,
             line: #line)
    }

    func testReportBrokenSiteSentPixel() {
        fire(NonStandardEvent(NonStandardPixel.brokenSiteReportSent),
             frequency: .standard,
             and: .expect(pixelName: "m_report-broken-site_sent"),
             file: #filePath,
             line: #line)
    }

    func testCommonSetOfFields() throws {
        let breakage = BrokenSiteReport(
            siteUrl: URL(string: "https://example.test/")!,
            category: "contentIsMissing",
            description: nil,
            osVersion: "12.3.0",
            manufacturer: "Apple",
            upgradedHttps: true,
            tdsETag: "abc123",
            configVersion: "123456789",
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
            protectionsState: true,
            reportFlow: .appMenu,
            errors: nil,
            httpStatusCodes: nil,
            openerContext: nil,
            vpnOn: false,
            jsPerformance: nil,
            userRefreshCount: 0
        )

        let urlRequest = makeURLRequest(with: breakage.requestParameters)

        let url = try XCTUnwrap(urlRequest.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: true))
        let queryItems = try XCTUnwrap(components.percentEncodedQueryItems)

        XCTAssertEqual(url.host, "improving.duckduckgo.com")
        XCTAssertEqual(url.path, "/t/epbf_macos_desktop")

        XCTAssertEqual(queryItems[valueFor: "category"], "contentIsMissing")
        XCTAssertEqual(queryItems[valueFor: "siteUrl"], "https%3A%2F%2Fexample.test%2F")
        XCTAssertEqual(queryItems[valueFor: "upgradedHttps"], "true")
        XCTAssertEqual(queryItems[valueFor: "tds"], "abc123")
        XCTAssertEqual(queryItems[valueFor: "blockedTrackers"], "bad.tracker.test,tracking.test")
        XCTAssertEqual(queryItems[valueFor: "surrogates"], "surrogate.domain.test")
        XCTAssertEqual(queryItems[valueFor: "protectionsState"], "true")
    }

    func testThatNativeAppSpecificFieldsAreReported() throws {
        let breakage = BrokenSiteReport(
            siteUrl: URL(string: "http://unsafe.example.test/path/to/thing.html")!,
            category: "videoOrImagesDidntLoad",
            description: nil,
            osVersion: "12",
            manufacturer: "Apple",
            upgradedHttps: false,
            tdsETag: "abc123",
            configVersion: "123456789",
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
            protectionsState: true,
            reportFlow: .appMenu,
            errors: nil,
            httpStatusCodes: nil,
            openerContext: nil,
            vpnOn: false,
            jsPerformance: nil,
            userRefreshCount: 0
        )

        let urlRequest = makeURLRequest(with: breakage.requestParameters)

        let url = try XCTUnwrap(urlRequest.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: true))
        let queryItems = try XCTUnwrap(components.percentEncodedQueryItems)

        XCTAssertEqual(url.host, "improving.duckduckgo.com")
        XCTAssertEqual(url.path, "/t/epbf_macos_desktop")

        XCTAssertEqual(queryItems[valueFor: "category"], "videoOrImagesDidntLoad")
        XCTAssertEqual(queryItems[valueFor: "siteUrl"], "http%3A%2F%2Funsafe.example.test%2Fpath%2Fto%2Fthing.html")
        XCTAssertEqual(queryItems[valueFor: "upgradedHttps"], "false")
        XCTAssertEqual(queryItems[valueFor: "tds"], "abc123")
        XCTAssertEqual(queryItems[valueFor: "blockedTrackers"], "bad.tracker.test,tracking.test")
        XCTAssertEqual(queryItems[valueFor: "surrogates"], "surrogate.domain.test")
        XCTAssertEqual(queryItems[valueFor: "protectionsState"], "true")
        XCTAssertEqual(queryItems[valueFor: "manufacturer"], "Apple")
        XCTAssertEqual(queryItems[valueFor: "os"], "12")
        XCTAssertEqual(queryItems[valueFor: "gpc"], "true")
    }

    func makeURLRequest(with parameters: [String: String]) -> URLRequest {
        APIRequest.Headers.setUserAgent("")
        var params = parameters
        params["test"] = "1"
        let configuration = APIRequest.Configuration(url: URL.pixelUrl(forPixelNamed: NonStandardPixel.brokenSiteReport.name),
                                                     queryParameters: params,
                                                     allowedQueryReservedCharacters: BrokenSiteReport.allowedQueryReservedCharacters)
        return configuration.request
    }
}

fileprivate extension Array where Element == URLQueryItem {

    subscript(valueFor name: String) -> String? {
        return first(where: { $0.name == name })?.value
    }
}
