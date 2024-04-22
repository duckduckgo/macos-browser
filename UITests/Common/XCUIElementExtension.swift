//
//  XCUIElementExtension.swift
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

extension XCUIElement {
    // https://stackoverflow.com/a/63089781/119717
    // Licensed under https://creativecommons.org/licenses/by-sa/4.0/
    // Credit: Adil Hussain

    /**
     * Waits the specified amount of time for the element’s `exists` property to become `false`.
     *
     * - Parameter timeout: The amount of time to wait.
     * - Returns: `false` if the timeout expires without the element coming out of existence.
     */
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let timeStart = Date().timeIntervalSince1970

        while Date().timeIntervalSince1970 <= (timeStart + timeout) {
            if !exists { return true }
        }

        return false
    }

    /// On some individual systems, strings which contain a ":" do not type the ":" when the string is entirely typed with `typeText(...)` into the
    /// address bar,
    /// wherever the ":" occurs in the string. This function stops before the ":" character and then types it with `typeKey(...)` as a workaround for
    /// this bug or unknown system setting.
    /// - Parameters:
    ///   - url: The URL to be typed into the address bar
    ///   - pressingEnter: If the `enter` key should not be pressed after typing this URL in, set this optional parameter to `false`, otherwise it
    /// will be pressed.
    func typeURL(_ url: URL, pressingEnter: Bool = true) {
        let urlString = url.absoluteString
        let urlParts = urlString.split(separator: ":")
        var completedURLSections = 0
        for urlPart in urlParts {
            self.typeText(String(urlPart))
            completedURLSections += 1
            if completedURLSections != urlParts.count {
                self.typeKey(":", modifierFlags: [])
            }
        }
        if pressingEnter {
            self.typeText("\r")
        }
    }

    /// Check for the existence of the address bar and type a URL into it if it passes. Although it doesn't really make sense to restrict its usage to
    /// the address bar, it is only foreseen and recommended for use with the address bar.
    /// - Parameters:
    ///   - url: The URL to be typed into the address bar (or other element, for which use with this function should be seen as experimental)
    ///   - pressingEnter: If the `enter` key should not be pressed after typing this URL in, set this optional parameter to `false`, otherwise it
    /// will be pressed.
    func typeURLAfterExistenceTestSucceeds(_ url: URL, pressingEnter: Bool = true) {
        XCTAssertTrue(
            self.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The element \(self.debugDescription) didn't load with the expected title in a reasonable timeframe."
        )
        self.typeURL(url, pressingEnter: pressingEnter)
    }

    func clickAfterExistenceTestSucceeds() {
        XCTAssertTrue(
            self.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "\(self.debugDescription) didn't load with the expected title in a reasonable timeframe."
        )
        self.click()
    }

    func hoverAfterExistenceTestSucceeds() {
        XCTAssertTrue(
            self.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "\(self.debugDescription) didn't load with the expected title in a reasonable timeframe."
        )
        self.hover()
    }
}
