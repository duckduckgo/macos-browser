//
//  DefaultVPNLocationFormatterTests.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser
@testable import NetworkProtection

final class DefaultVPNLocationFormatterTests: XCTestCase {
    private var formatter: DefaultVPNLocationFormatter!

    override func setUp() {
        formatter = DefaultVPNLocationFormatter()
    }

    func testUSLocation() {
        let server = NetworkProtectionServerInfo.ServerAttributes(city: "Lafayette", country: "us", state: "la", timezoneOffset: 0)
        let preferredLocation = VPNSettings.SelectedLocation.location(.init(country: "us"))

        XCTAssertNil(formatter.emoji(for: nil))
        XCTAssertEqual(formatter.emoji(for: server.country), "🇺🇸")

        XCTAssertEqual(formatter.string(from: nil, preferredLocation: .nearest), "Nearest available")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: .nearest), "Lafayette, LA (Nearest)")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: preferredLocation), "Lafayette, LA")

        if #available(macOS 12, *) {
            XCTAssertEqual(NSAttributedString(formatter.string(from: server.serverLocation,
                                                               preferredLocation: .nearest,
                                                               locationTextColor: .black,
                                                               preferredLocationTextColor: .black)).string, "Lafayette, LA (Nearest)")
            XCTAssertEqual(NSAttributedString(formatter.string(from: server.serverLocation,
                                                               preferredLocation: preferredLocation,
                                                               locationTextColor: .black,
                                                               preferredLocationTextColor: .black)).string, "Lafayette, LA")
        }
    }

    func testCALocation() {
        let server = NetworkProtectionServerInfo.ServerAttributes(city: "Toronto", country: "ca", state: "on", timezoneOffset: 0)
        let preferredLocation = VPNSettings.SelectedLocation.location(.init(country: "ca"))

        XCTAssertNil(formatter.emoji(for: nil))
        XCTAssertEqual(formatter.emoji(for: server.country), "🇨🇦")

        XCTAssertEqual(formatter.string(from: nil, preferredLocation: .nearest), "Nearest available")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: .nearest), "Toronto, Canada (Nearest)")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: preferredLocation), "Toronto, Canada")

        if #available(macOS 12, *) {
            XCTAssertEqual(NSAttributedString(formatter.string(from: server.serverLocation,
                                                               preferredLocation: .nearest,
                                                               locationTextColor: .black,
                                                               preferredLocationTextColor: .black)).string, "Toronto, Canada (Nearest)")
            XCTAssertEqual(NSAttributedString(formatter.string(from: server.serverLocation,
                                                               preferredLocation: preferredLocation,
                                                               locationTextColor: .black,
                                                               preferredLocationTextColor: .black)).string, "Toronto, Canada")
        }
    }
}
