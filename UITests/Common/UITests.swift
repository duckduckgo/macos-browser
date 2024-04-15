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
import XCTest

/// Helper values for the UI tests
enum UITests {
    /// Timeout constants for different test requirements
    enum Timeouts {
        /// Mostly, we use timeouts to wait for element existence. This is about 3x longer than needed, for CI resilience
        static let elementExistence: Double = 5.0
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

    /// This is intended for setting an autocomplete checkbox state that extends across all test cases and is only run once in the class override
    /// setup() of the case. Setting the autocomplete checkbox state for an individual test shouldn't start and terminate the app, as this function
    /// does.
    /// - Parameter requestedToggleState: How the autocomplete checkbox state should be set
    static func setAutocompleteToggleBeforeTestcaseRuns(_ requestedToggleState: Bool) {
        let app = XCUIApplication()
        app.launch()

        app.typeKey(",", modifierFlags: [.command]) // Open settings
        let generalPreferencesButton = app.buttons["PreferencesSidebar.generalButton"]
        let autocompleteToggle = app.checkBoxes["PreferencesGeneralView.showAutocompleteSuggestions"]
        XCTAssertTrue(
            generalPreferencesButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The user settings appearance section button didn't become available in a reasonable timeframe."
        )
        generalPreferencesButton.click(forDuration: 0.5, thenDragTo: generalPreferencesButton)

        let currentToggleState = try? XCTUnwrap(
            autocompleteToggle.value as? Bool,
            "It wasn't possible to get the \"Autocomplete\" value as a Bool"
        )

        switch (requestedToggleState, currentToggleState) { // Click autocomplete toggle if it is different than our request
        case (false, true), (true, false):
            autocompleteToggle.click()
        default:
            break
        }
        app.terminate()
    }

    /// A debug function that is going to need some other functionality in order to be useful for debugging address bar focus issues
    static func openVanillaBrowser() {
        let app = XCUIApplication()
        let openVanillaBrowser = app.menuItems["MainMenu.openVanillaBrowser"]
        openVanillaBrowser.clickAfterExistenceTestSucceeds()
        app.typeKey("w", modifierFlags: [.command, .option])
    }

    /// Avoid some first-run states that we aren't testing.
    static func firstRun() {
        let notificationCenter = XCUIApplication(bundleIdentifier: "com.apple.UserNotificationCenter")
        if notificationCenter.exists { // If tests-server is asking for network permissions, deny them.
            notificationCenter.typeKey(.escape, modifierFlags: [])
        }
        let app = XCUIApplication()
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        app.typeKey("w", modifierFlags: [.command, .option])
        app.terminate()
    }
}
