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
        let server = NetworkProtectionServerInfo.ServerAttributes(city: "Lafayette", country: "us", state: "la")
        let preferredLocation = VPNSettings.SelectedLocation.location(.init(country: "us"))
        let otherPreferredLocation = VPNSettings.SelectedLocation.location(.init(country: "gb"))

        XCTAssertNil(formatter.emoji(for: nil, preferredLocation: .nearest))
        XCTAssertEqual(formatter.emoji(for: nil, preferredLocation: preferredLocation), "🇺🇸")
        XCTAssertEqual(formatter.emoji(for: nil, preferredLocation: otherPreferredLocation), "🇬🇧")
        XCTAssertEqual(formatter.emoji(for: server.country, preferredLocation: preferredLocation), "🇺🇸")
        XCTAssertEqual(formatter.emoji(for: server.country, preferredLocation: otherPreferredLocation), "🇺🇸")

        XCTAssertEqual(formatter.string(from: nil, preferredLocation: .nearest), "Nearest Location")
        XCTAssertEqual(formatter.string(from: nil, preferredLocation: preferredLocation), "United States")
        XCTAssertEqual(formatter.string(from: nil, preferredLocation: otherPreferredLocation), "United Kingdom")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: .nearest), "Lafayette, United States (Nearest)")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: preferredLocation), "Lafayette, United States")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: otherPreferredLocation), "Lafayette, United States")

        if #available(macOS 12, *) {
            XCTAssertEqual(NSAttributedString(formatter.string(from: server.serverLocation,
                                                               preferredLocation: .nearest,
                                                               locationTextColor: .black,
                                                               preferredLocationTextColor: .black)).string, "Lafayette, United States (Nearest)")
            XCTAssertEqual(NSAttributedString(formatter.string(from: server.serverLocation,
                                                               preferredLocation: preferredLocation,
                                                               locationTextColor: .black,
                                                               preferredLocationTextColor: .black)).string, "Lafayette, United States")
        }
    }

    func testCALocation() {
        let server = NetworkProtectionServerInfo.ServerAttributes(city: "Toronto", country: "ca", state: "on")
        let preferredLocation = VPNSettings.SelectedLocation.location(.init(country: "ca"))
        let otherPreferredLocation = VPNSettings.SelectedLocation.location(.init(country: "gb"))

        XCTAssertNil(formatter.emoji(for: nil, preferredLocation: .nearest))
        XCTAssertEqual(formatter.emoji(for: nil, preferredLocation: preferredLocation), "🇨🇦")
        XCTAssertEqual(formatter.emoji(for: nil, preferredLocation: otherPreferredLocation), "🇬🇧")
        XCTAssertEqual(formatter.emoji(for: server.country, preferredLocation: preferredLocation), "🇨🇦")
        XCTAssertEqual(formatter.emoji(for: server.country, preferredLocation: otherPreferredLocation), "🇨🇦")

        XCTAssertEqual(formatter.string(from: nil, preferredLocation: .nearest), "Nearest Location")
        XCTAssertEqual(formatter.string(from: nil, preferredLocation: preferredLocation), "Canada")
        XCTAssertEqual(formatter.string(from: nil, preferredLocation: otherPreferredLocation), "United Kingdom")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: .nearest), "Toronto, Canada (Nearest)")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: preferredLocation), "Toronto, Canada")
        XCTAssertEqual(formatter.string(from: server.serverLocation, preferredLocation: otherPreferredLocation), "Toronto, Canada")

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
