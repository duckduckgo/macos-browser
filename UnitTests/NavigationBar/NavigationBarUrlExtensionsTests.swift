//
//  NavigationBarUrlExtensionsTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

final class NavigationBarUrlExtensionsTests: XCTestCase {

    func testLocalURLDetection() {
        let localURLs: [String] = [
            "http://localhost",
            "http://example.local",
            "http://localhost.localhost",
            "http://172.16.0.0",
            "http://172.31.255.255",
            "http://172.18.100.204",
            "http://172.18.100.3",
            "http://10.0.0.0",
            "http://10.0.0.18",
            "http://10.255.255.255",
            "http://192.168.0.0",
            "http://192.168.56.5",
            "http://192.168.255.255",
            "http://169.254.0.0",
            "http://169.254.200.56",
            "http://169.254.255.255",
            "http://[fc00::1]",
            "http://[fe80::1]",
            "http://[::1]",
            "http://[fe80::1]",
            "http://[fc00::2]",
            "http://[fe80::2]"
        ]

        let nonLocalURLs: [String] = [
            "http://example.com",
            "http://localhost.localhost.co.uk",
            "http://172.0.0.0",
            "http://172.15.0.0",
            "http://172.19.256.100",
            "http://172.23.255.256",
            "http://10.256.0.56",
            "http://10.100.256.7",
            "http://10.255.255.256",
            "http://191.168.0.0",
            "http://193.168.0.0",
            "http://192.169.0.0",
            "http://192.167.0.0",
            "http://192.168.256.12",
            "http://192.168.255.256",
            "http://170.254.0.0",
            "http://168.254.0.0",
            "http://169.255.0.0",
            "http://169.253.0.0",
            "http://169.254.256.0",
            "http://169.254.0.256",
            "http://[2001:db8::1]",
            "http://[fd00::2]",
            "http://[fe81::1]",
            "http://[fe79::2]"
        ]

            for url in localURLs {
                XCTAssertTrue(URL(string: url)?.isLocalURL ?? false, "\(url) should be detected as a local URL")
            }

            for url in nonLocalURLs {
                XCTAssertFalse(URL(string: url)?.isLocalURL ?? true, "\(url) should not be detected as a local URL")
            }
        }
}
