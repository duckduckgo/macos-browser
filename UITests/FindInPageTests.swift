//
//  FindInPageTests.swift
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

class FindInPageTests: XCTestCase {
    let app = XCUIApplication()
    let timeout = 0.3
    let searchOrEnterAddressTextField = XCUIApplication().windows.textFields["AddressBarViewController.addressBarTextField"]
    let loremIpsumWebView = XCUIApplication().windows.webViews["Lorem Ipsum"]
    let findInPageCloseButton = XCUIApplication().windows.buttons["FindInPageController.closeButton"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        saveLocalHTML()
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: .command)
        
    }

    override func tearDownWithError() throws {
        removeLocalHTML()
    }

    func test_findInPage_canBeOpenedWithKeyCommand() throws {
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: timeout), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local lorem ipsum web page didn't load with the expected title in a reasonable timeframe.")

        app.typeKey("f", modifierFlags: .command)

        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking find in page with command-f, the elements of the find in page interface should exist.")
    }

    func test_findInPage_canBeOpenedWithMenuBarItem() throws {
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: timeout), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local lorem ipsum web page didn't load with the expected title in a reasonable timeframe.")
        let findInPageMenuBarItem = app.menuItems["MainMenu.findInPage"]
        XCTAssertTrue(findInPageMenuBarItem.waitForExistence(timeout: timeout), "Couldn't find Find in Page menu bar item in a reasonable timeframe.")

        findInPageMenuBarItem.click()

        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking find in page via the menu items Edit->Find->Find in Page, the elements of the find in page interface should exist.")
    }

    func test_findInPage_canBeOpenedWithMoreOptionsMenuItem() throws {
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: timeout), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local lorem ipsum web page didn't load with the expected title in a reasonable timeframe.")
        let optionsButton = XCUIApplication().windows.buttons["NavigationBarViewController.optionsButton"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: timeout), "Couldn't find options item in a reasonable timeframe.")
        optionsButton.click()

        let findInPageMoreOptionsMenuBarItem = app.menuItems["MoreOptionsMenu.findInPage"]
        XCTAssertTrue(findInPageMoreOptionsMenuBarItem.waitForExistence(timeout: timeout), "Couldn't find more options find in page menu item in a reasonable timeframe.")
        findInPageMoreOptionsMenuBarItem.click()

        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking find in page via the more options find in Page menu item, the elements of the find in page interface should exist.")
    }

    func test_findInPage_canBeClosedWithEscape() throws {
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: timeout), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local lorem ipsum web page didn't load with the expected title in a reasonable timeframe.")
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking find in page with command-f, the elements of the find in page interface should exist.")

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(findInPageCloseButton.waitForNonExistence(timeout: timeout), "After closing find in page with escape, the elements of the find in page interface should no longer exist.")
    }

    func test_findInPage_canBeClosedWithShiftCommandF() throws {
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: timeout), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local lorem ipsum web page didn't load with the expected title in a reasonable timeframe.")
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking find in page with command-f, the elements of the find in page interface should exist.")

        app.typeKey("f", modifierFlags: [.command, .shift])

        XCTAssertTrue(findInPageCloseButton.waitForNonExistence(timeout: timeout), "After closing find in page with escape, the elements of the find in page interface should no longer exist.")
    }

    func test_findInPage_canBeClosedWithHideFindMenuItem() throws {
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: timeout), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local lorem ipsum web page didn't load with the expected title in a reasonable timeframe.")
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking find in page with command-f, the elements of the find in page interface should exist.")

        let findInPageDoneMenuBarItem = app.menuItems["MainMenu.findInPageDone"]
        XCTAssertTrue(findInPageDoneMenuBarItem.waitForExistence(timeout: timeout), "Couldn't find find in page done main menu item in a reasonable timeframe.")
        findInPageDoneMenuBarItem.click()

        XCTAssertTrue(findInPageCloseButton.waitForNonExistence(timeout: timeout), "After closing find in page with escape, the elements of the find in page interface should no longer exist.")
    }

    func test_findInPage_showsCorrectNumberOfOccurences() throws {
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: timeout), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local lorem ipsum web page didn't load with the expected title in a reasonable timeframe.")
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking find in page with command-f, the elements of the find in page interface should exist.")

        app.typeText("maximus\r")
        let statusField = app.textFields["FindInPageController.statusField"]
        XCTAssertTrue(statusField.waitForExistence(timeout: timeout), "Couldn't find find in page statusField in a reasonable timeframe.")
        XCTAssertNotNil(statusField.value as? String, "There was no string content in the find in page status field when it was expected.")
        let statusFieldTextContent = statusField.value as! String

        XCTAssertEqual(statusFieldTextContent, "1 of 6") // Note: this is not a localized test element, and it should have a localization strategy.
    }
}

extension FindInPageTests {
    func loremIpsumFileURL() -> URL {
        let loremIpsumFileName = "lorem_ipsum.html"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let loremIpsumHTMLFileURL = documentsDirectory.appendingPathComponent(loremIpsumFileName)
        return loremIpsumHTMLFileURL
    }

    func saveLocalHTML() {
        let loremIpsumHTML = """
        <html><head><title>Lorem Ipsum</title></head><body><table><tr><td><p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi ac sem nisi. Cras fermentum mi vitae turpis efficitur malesuada. Donec eget maximus ligula, et tincidunt sapien. Suspendisse posuere diam maximus, dignissim ex at, fringilla elit. Maecenas enim tellus, ornare non pretium a, sodales nec lectus. Vestibulum quis augue orci. Donec eget mi sed magna consequat auctor a a nulla. Etiam condimentum, neque at congue semper, arcu sem commodo tellus, venenatis finibus ex magna vitae erat. Nunc non enim sit amet mi posuere egestas. Donec nibh nisl, pretium sit amet aliquet, porta id nibh. Pellentesque ullamcorper mauris quam, semper hendrerit mi dictum non. Nullam pulvinar, nulla a maximus egestas, velit mi volutpat neque, vitae placerat eros sapien vitae tellus. Pellentesque malesuada accumsan dolor, ut feugiat enim. Curabitur nunc quam, maximus venenatis augue vel, accumsan eros.</p>

        <p>Donec consequat ultrices ante non maximus. Quisque eu semper diam. Nunc ullamcorper eget ex id luctus. Duis metus ex, dapibus sit amet vehicula eget, rhoncus eget lacus. Nulla maximus quis turpis vel pulvinar. Duis neque ligula, tristique et diam ut, fringilla sagittis arcu. Vestibulum suscipit semper lectus, quis placerat ex euismod eu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae;</p>

        <p>Maecenas odio orci, eleifend et ipsum nec, interdum dictum turpis. Nunc nec velit diam. Sed nisl risus, imperdiet sit amet tempor ut, laoreet sed lorem. Aenean egestas ullamcorper sem. Sed accumsan vehicula augue, vitae tempor augue tincidunt id. Morbi ullamcorper posuere lacus id tempus. Ut vel tincidunt quam, quis consectetur velit. Mauris id lorem vitae odio consectetur vehicula. Vestibulum viverra scelerisque porta. Vestibulum eu consequat urna. Etiam dignissim ullamcorper faucibus.</p></td></tr></table></body></html>
        """
        let loremIpsumData = Data(loremIpsumHTML.utf8)

        do {
            try loremIpsumData.write(to: loremIpsumFileURL(), options: [])
        } catch {
            print(error.localizedDescription)
        }
    }

    func removeLocalHTML() {
        do {
            try FileManager.default.removeItem(at: loremIpsumFileURL())
        } catch {
            print(error.localizedDescription)
        }
    }
}

extension XCUIElement {
    // https://stackoverflow.com/a/37447150/119717

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
}
