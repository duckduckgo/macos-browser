//
//  AddressBarKeyboardShortcutsTests.swift
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

class AddressBarKeyboardShortcutsTests: XCTestCase {
    private var app: XCUIApplication!
    private var urlStringForAddressBar: String!
    private var urlForAddressBar: URL!

    private var addressBarTextField: XCUIElement!
    override class func setUp() {
        UITests.setAutocompleteToggleBeforeTestcaseRuns(false) // We don't want changes in the address bar that we don't create
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        urlStringForAddressBar = "https://duckduckgo.com/duckduckgo-help-pages/results/translation/"
        urlForAddressBar = URL(string: urlStringForAddressBar)
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: .command)
        addressBarTextField.typeURL(urlForAddressBar, pressingEnter: false)
    }

    func test_addressBar_end_canBeNavigatedToWithCommandRightArrow() throws {
        addressBarTextField.typeKey(.rightArrow, modifierFlags: .command) // This is the behavior under test, but we will have to verify it indirectly

        let charactersToTrimFromSuffix = 13
        selectCharacters(direction: DirectionKey.left, numberOfCharacters: charactersToTrimFromSuffix)
        app.typeKey(.delete, modifierFlags: .command)
        let addressFieldContentsAfterDelete = try XCTUnwrap(addressBarTextField.value as? String).removingTagLine()
        let urlMinusDeletedCharacters: String = try XCTUnwrap(String(urlStringForAddressBar.dropLast(charactersToTrimFromSuffix)))

        XCTAssertEqual(
            urlMinusDeletedCharacters,
            addressFieldContentsAfterDelete,
            "If the contents of the address bar minus the last \(charactersToTrimFromSuffix) characters from selecting backwards and deleting doesn't match the original URL string minus its last \(charactersToTrimFromSuffix), we were not at the end of the address bar string after typing command-right-arrow"
        )
    }

    func test_addressBar_beginning_canBeNavigatedToWithCommandLeftArrow() throws {
        addressBarTextField.typeKey(.leftArrow, modifierFlags: .command) // This is the behavior under test, but we will have to verify it indirectly

        let charactersToTrimFromPrefix = 5
        selectCharacters(direction: DirectionKey.right, numberOfCharacters: charactersToTrimFromPrefix)
        app.typeKey(.delete, modifierFlags: .command)
        let addressFieldContentsAfterDelete = try XCTUnwrap(addressBarTextField.value as? String).removingTagLine()
        let urlMinusDeletedCharacters: String = try XCTUnwrap(String(urlStringForAddressBar.dropFirst(charactersToTrimFromPrefix)))

        XCTAssertEqual(
            urlMinusDeletedCharacters,
            addressFieldContentsAfterDelete,
            "If the contents of the address bar minus the first \(charactersToTrimFromPrefix) characters from selecting forwards and deleting doesn't match the original URL string minus its first \(charactersToTrimFromPrefix), we were not at the start of the address bar string after typing command-left-arrow"
        )
    }

    /// An important note about this test: option-arrow does not navigate through URL components, but through certain word boundary characters such as
    /// "/", and possibly including others such as "-", and ".", meaning that it often navigates through URL components as a side-effect, but not
    /// always. The
    /// list of word boundary characters isn't documented. This test tests whether option-arrow moves the caret between two backslashes where no other
    /// word
    /// boundary characters are present: it doesn't try to test other word boundaries, and it isn't a test which demonstrates movement between URL
    /// components,
    /// since results would be different if there were a word boundary character inside of the components it targets. This is also true of the
    /// option-right-arrow test.
    func test_addressBar_caret_canNavigateThroughWordBoundariesUsingOptionLeftArrow() throws {
        addressBarTextField.typeKey(.rightArrow, modifierFlags: .command) // move caret to end
        addressBarTextField.typeKey(.leftArrow, modifierFlags: .option) // Step back twice using option-left-arrow

        addressBarTextField.typeKey(.leftArrow, modifierFlags: .option) // This is the behavior under test, but we will have to verify it indirectly
        addressBarTextField.typeKey(.rightArrow, modifierFlags: [.command, .shift]) // Select all text to the right of the caret
        addressBarTextField.typeKey(.delete, modifierFlags: []) // Delete it
        let addressFieldContentsAfterDelete = try XCTUnwrap(addressBarTextField.value as? String).removingTagLine()
        let urlMinusDeletedCharacters: String = try XCTUnwrap(String(urlStringForAddressBar.replacingOccurrences(
            of: "results/translation/",
            // Delete the last two components we expected to be deleted in our address bar navigation process from the original reference string for
            // comparison
            with: ""
        )))

        XCTAssertEqual(
            urlMinusDeletedCharacters,
            addressFieldContentsAfterDelete,
            "If the address field contents after we have navigated using option-left-arrow do not match our expectation string, that means that at the time we selected the remainder of the address bar string and deleted it, option-left-arrow had not navigated the caret to the insertion point it should have."
        )
    }

    /// Note: please read `test_addressBar_caret_canNavigateThroughWordBoundariesUsingOptionLeftArrow()`
    /// for more information about what this test tests, and does not test.
    func test_addressBar_caret_canNavigateThroughWordBoundariesUsingOptionRightArrow() throws {
        addressBarTextField.typeKey(.rightArrow, modifierFlags: .command) // move caret to end
        addressBarTextField.typeKey(.leftArrow, modifierFlags: .option) // Step back twice using option-left-arrow.
        addressBarTextField
            .typeKey(.leftArrow,
                     modifierFlags: .option) // Arranging so we can test option-right-arrow in an area with no other word boundary characters.

        addressBarTextField.typeKey(.rightArrow, modifierFlags: .option) // This is the behavior under test, but we will have to verify it indirectly
        addressBarTextField.typeKey(.leftArrow, modifierFlags: [.option, .shift]) // Select the component to the left of the caret
        addressBarTextField.typeKey(.delete, modifierFlags: []) // Delete it
        let addressFieldContentsAfterDelete = try XCTUnwrap(addressBarTextField.value as? String).removingTagLine()
        let urlMinusDeletedCharacters: String = try XCTUnwrap(String(urlStringForAddressBar.replacingOccurrences(
            of: "results",
            // Delete the last component we expected to be deleted in our address bar navigation process from the original reference string for
            // comparison
            with: ""
        )))

        XCTAssertEqual(
            urlMinusDeletedCharacters,
            addressFieldContentsAfterDelete,
            "If the address field contents after we have navigated using option-right-arrow and deleted part of the URL to the left of the caret insertion point do not match our expectation string, that means that at the time we selected the part of the address bar string next to the insertion point and deleted it, option-right-arrow had not navigated the caret to the insertion point it should have."
        )
    }
}

private extension AddressBarKeyboardShortcutsTests {
    func selectCharacters(direction: XCUIKeyboardKey, numberOfCharacters: Int) {
        for _ in 1 ... numberOfCharacters {
            addressBarTextField.typeKey(direction, modifierFlags: [.shift])
        }
    }

    enum DirectionKey {
        static let right: XCUIKeyboardKey = .rightArrow
        static let left: XCUIKeyboardKey = .leftArrow
    }
}

private extension String {
    func removingTagLine() -> String {
        return self.components(separatedBy: " ").first ?? self // If there is no space in the URL, the tagline isn't attached
    }
}
