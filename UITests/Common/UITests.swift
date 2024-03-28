//
//  UITests.swift
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

/// Helper values for the UI tests
enum UITests {
    /// Timeout constants for different test requirements
    enum Timeouts {
        /// Mostly, we use timeouts to wait for element existence. This is about 3x longer than needed, for CI resilience
        static let elementExistence: Double = 2.5
        /// The fire animation time has environmental dependencies, so we want to wait for completion so we don't try to type into it
        static let fireAnimation: Double = 30.0
    }

    /// A page simple enough to test favorite, bookmark, and history storage
    /// - Parameter title: The title of the page to match
    /// - Returns: A URL that can be served by `tests-server`
    static func simpleServedPage(titled title: String) -> URL {
        return URL.testsServer
            .appendingTestParameters(data: """
            <html>
            <head>
            <title>\(title)</title>
            </head>
            <body>
            <p>Sample text</p>
            </body>
            </html>
            """.utf8data)
    }

    static func randomPageTitle(length: Int) -> String {
        return String(UUID().uuidString.prefix(length))
    }
}
