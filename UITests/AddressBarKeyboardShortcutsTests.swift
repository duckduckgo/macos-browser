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

    private var addressBarTextField: XCUIElement!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        urlStringForAddressBar = "https://duckduckgo.com/duckduckgo-help-pages/company/short-domain/"
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: .command)
    }

    func test_addressBar_end_canBeNavigatedToWithCommandRightArrow() throws {
        addressBarTextField.typeURL(URL(string: urlStringForAddressBar)!, pressingEnter: false)
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
        return self.replacingOccurrences(
            of: " – Visit duckduckgo.com",
            with: ""
        )
    }
}
