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

class FindInPageTests: UITestCase {
    private var app: XCUIApplication!
    private var addressBarTextField: XCUIElement!
    private var loremIpsumWebView: XCUIElement!
    private var findInPageCloseButton: XCUIElement!
    private let minimumExpectedMatchingPixelsInFindHighlight = 150

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
        saveLocalHTML()
    }

    override class func tearDown() {
        super.tearDown()
        removeLocalHTML()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        loremIpsumWebView = app.windows.webViews["Lorem Ipsum"]
        findInPageCloseButton = app.windows.buttons["FindInPageController.closeButton"]
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: .command)
    }

    func test_findInPage_canBeOpenedWithKeyCommand() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )

        app.typeKey("f", modifierFlags: .command)

        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )
    }

    func test_findInPage_canBeOpenedWithMenuBarItem() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        let findInPageMenuBarItem = app.menuItems["MainMenu.findInPage"]
        XCTAssertTrue(
            findInPageMenuBarItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find in Page\" main menu bar item in a reasonable timeframe."
        )

        findInPageMenuBarItem.click()

        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" via the menu items Edit->Find->\"Find in Page\", the elements of the \"Find in Page\" interface should exist."
        )
    }

    func test_findInPage_canBeOpenedWithMoreOptionsMenuItem() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        let optionsButton = app.windows.buttons["NavigationBarViewController.optionsButton"]
        optionsButton.clickAfterExistenceTestSucceeds()

        let findInPageMoreOptionsMenuItem = app.menuItems["MoreOptionsMenu.findInPage"]
        XCTAssertTrue(
            findInPageMoreOptionsMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find More Options \"Find in Page\" menu item in a reasonable timeframe."
        )
        findInPageMoreOptionsMenuItem.click()

        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" via the More Options \"Find in Page\" menu item, the elements of the \"Find in Page\" interface should exist."
        )
    }

    func test_findInPage_canBeClosedWithEscape() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(
            findInPageCloseButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "After closing \"Find in Page\" with escape, the elements of the \"Find in Page\" interface should no longer exist."
        )
    }

    func test_findInPage_canBeClosedWithShiftCommandF() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )

        app.typeKey("f", modifierFlags: [.command, .shift])

        XCTAssertTrue(
            findInPageCloseButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "After closing \"Find in Page\" with escape, the elements of the \"Find in Page\" interface should no longer exist."
        )
    }

    func test_findInPage_canBeClosedWithHideFindMenuItem() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )

        let findInPageDoneMenuBarItem = app.menuItems["MainMenu.findInPageDone"]
        XCTAssertTrue(
            findInPageDoneMenuBarItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find in Page\" done main menu item in a reasonable timeframe."
        )
        findInPageDoneMenuBarItem.click()

        XCTAssertTrue(
            findInPageCloseButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "After closing \"Find in Page\" with escape, the elements of the \"Find in Page\" interface should no longer exist."
        )
    }

    func test_findInPage_showsCorrectNumberOfOccurrences() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )

        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )

        app.typeText("maximus\r")
        let statusField = app.textFields["FindInPageController.statusField"]
        XCTAssertTrue(
            statusField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find in Page\" statusField in a reasonable timeframe."
        )
        let statusFieldTextContent = try XCTUnwrap(statusField.value as? String)
        XCTAssertEqual(statusFieldTextContent, "1 of 4") // Note: this is not a localized test element, and it should have a localization strategy.
    }

    func test_findInPage_showsFocusAndOccurrenceHighlighting() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )

        app.typeText("maximus\r")
        let statusField = app.textFields["FindInPageController.statusField"]
        XCTAssertTrue(
            statusField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find in Page\" statusField in a reasonable timeframe."
        )
        let statusFieldTextContent = try XCTUnwrap(statusField.value as? String)
        // Note: the following is not a localized test element, but it should have a localization strategy.
        XCTAssertEqual(statusFieldTextContent, "1 of 4", "Unexpected status field text content after a \"Find in Page\" operation.")

        let webViewWithSelectedWordsScreenshot = loremIpsumWebView.screenshot()
        let highlightedPixelsInScreenshot = try XCTUnwrap(webViewWithSelectedWordsScreenshot.image.matchingPixels(of: .findHighlightColor))
        XCTAssertGreaterThan(
            highlightedPixelsInScreenshot.count,
            minimumExpectedMatchingPixelsInFindHighlight,
            "There are expected to be more than \(minimumExpectedMatchingPixelsInFindHighlight) pixels of NSColor.findHighlightColor in a screenshot of a \"Find in Page\" search where there is a match, but this test found \(highlightedPixelsInScreenshot) matching pixels."
        )
    }

    func test_findNext_menuItemGoesToNextOccurrence() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )
        app.typeText("maximus\r")
        let statusField = app.textFields["FindInPageController.statusField"]
        XCTAssertTrue(
            statusField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find in Page\" statusField in a reasonable timeframe."
        )
        let statusFieldTextContent = try XCTUnwrap(statusField.value as? String)
        // Note: the following is not a localized test element, but it should have a localization strategy.
        XCTAssertEqual(statusFieldTextContent, "1 of 4", "Unexpected status field text content after a \"Find in Page\" operation.")
        let findInPageScreenshot = loremIpsumWebView.screenshot()
        let highlightedPixelsInFindScreenshot = try XCTUnwrap(findInPageScreenshot.image.matchingPixels(of: .findHighlightColor))
        let findHighlightPoints = Set(highlightedPixelsInFindScreenshot.map { $0.point }) // Coordinates of highlighted pixels in the find screenshot

        let findNextMenuBarItem = app.menuItems["MainMenu.findNext"]
        XCTAssertTrue(
            findNextMenuBarItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find Next\" main menu bar item in a reasonable timeframe."
        )
        findNextMenuBarItem.click()
        let updatedStatusField = app.textFields["FindInPageController.statusField"]
        let updatedStatusFieldTextContent = updatedStatusField.value as! String
        XCTAssertTrue(
            updatedStatusField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find the updated \"Find in Page\" statusField in a reasonable timeframe."
        )
        XCTAssertEqual(updatedStatusFieldTextContent, "2 of 4", "Unexpected status field text content after a \"Find Next\" operation.")
        let findNextScreenshot = loremIpsumWebView.screenshot()
        let highlightedPixelsInFindNextScreenshot =
            try XCTUnwrap(Set(findNextScreenshot.image
                    .matchingPixels(of: .findHighlightColor))) // Coordinates of highlighted pixels in the find next screenshot
        let findNextHighlightPoints = highlightedPixelsInFindNextScreenshot.map { $0.point }
        let pixelSetIntersection = findHighlightPoints
            .intersection(findNextHighlightPoints) // If the highlighted text has moved as expected, this should not have many elements

        XCTAssertGreaterThan(
            highlightedPixelsInFindNextScreenshot.count,
            minimumExpectedMatchingPixelsInFindHighlight,
            "There are expected to be more than \(minimumExpectedMatchingPixelsInFindHighlight) pixels of NSColor.findHighlightColor in a screenshot of a \"Find in Page\" search where there is a match for a \"Find next\" operation, but this test found \(highlightedPixelsInFindNextScreenshot) matching pixels."
        )
        XCTAssertTrue(
            pixelSetIntersection.count <= findNextHighlightPoints.count / 2,
            "When the selection rectangle has moved as expected, fewer than half of the highlighted pixel coordinates from \"Find Next\" should intersect with the highlighted pixel coordinates from the initial \"Find\" operation."
        )
    }

    func test_findNext_nextArrowGoesToNextOccurrence() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )
        app.typeText("maximus\r")
        let statusField = app.textFields["FindInPageController.statusField"]
        XCTAssertTrue(
            statusField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find in Page\" statusField in a reasonable timeframe."
        )
        let statusFieldTextContent = try XCTUnwrap(statusField.value as? String)
        // Note: the following is not a localized test element, but it should have a localization strategy.
        XCTAssertEqual(statusFieldTextContent, "1 of 4", "Unexpected status field text content after a \"Find in Page\" operation.")
        let findInPageScreenshot = loremIpsumWebView.screenshot()
        let highlightedPixelsInFindScreenshot = try XCTUnwrap(findInPageScreenshot.image.matchingPixels(of: .findHighlightColor))
        let findHighlightPoints = Set(highlightedPixelsInFindScreenshot.map { $0.point }) // Coordinates of highlighted pixels in the find screenshot
        let findInPageNextButton = app.windows.buttons["FindInPageController.nextButton"]
        XCTAssertTrue(
            findInPageNextButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find Next\" main menu bar item in a reasonable timeframe."
        )

        findInPageNextButton.click()
        let updatedStatusField = app.textFields["FindInPageController.statusField"]
        let updatedStatusFieldTextContent = updatedStatusField.value as! String
        XCTAssertTrue(
            updatedStatusField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find the updated \"Find in Page\" statusField in a reasonable timeframe."
        )
        XCTAssertEqual(updatedStatusFieldTextContent, "2 of 4", "Unexpected status field text content after a \"Find Next\" operation.")
        let findNextScreenshot = loremIpsumWebView.screenshot()
        let highlightedPixelsInFindNextScreenshot = try XCTUnwrap(findNextScreenshot.image.matchingPixels(of: .findHighlightColor))
        let findNextHighlightPoints = highlightedPixelsInFindNextScreenshot.map { $0.point }
        let pixelSetIntersection = findHighlightPoints
            .intersection(findNextHighlightPoints) // If the highlighted text has moved as expected, this should not have many elements

        XCTAssertGreaterThan(
            highlightedPixelsInFindNextScreenshot.count,
            minimumExpectedMatchingPixelsInFindHighlight,
            "There are expected to be more than \(minimumExpectedMatchingPixelsInFindHighlight) pixels of NSColor.findHighlightColor in a screenshot of a \"Find in Page\" search where there is a match, but this test found \(highlightedPixelsInFindNextScreenshot) matching pixels."
        )
        XCTAssertTrue(
            pixelSetIntersection.count <= findNextHighlightPoints.count / 2,
            "When the selection rectangle has moved as expected, fewer than half of the highlighted pixel coordinates from \"Find Next\" should intersect with the highlighted pixel coordinates from the initial \"Find\" operation."
        )
    }

    func test_findNext_commandGGoesToNextOccurrence() throws {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(Self.loremIpsumFileURL)
        XCTAssertTrue(
            loremIpsumWebView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe. If this is unexpected, it can also be due to the timeout being too short."
        )
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(
            findInPageCloseButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist."
        )
        app.typeText("maximus\r")
        let statusField = app.textFields["FindInPageController.statusField"]
        XCTAssertTrue(
            statusField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find \"Find in Page\" statusField in a reasonable timeframe."
        )
        let statusFieldTextContent = try XCTUnwrap(statusField.value as? String)

        // Note: the following is not a localized test element, but it should have a localization strategy.
        XCTAssertEqual(statusFieldTextContent, "1 of 4", "Unexpected status field text content after a \"Find in Page\" operation.")
        let findInPageScreenshot = loremIpsumWebView.screenshot()
        let highlightedPixelsInFindScreenshot = try XCTUnwrap(findInPageScreenshot.image.matchingPixels(of: .findHighlightColor))
        let findHighlightPoints = Set(highlightedPixelsInFindScreenshot.map { $0.point }) // Coordinates of highlighted pixels in the find screenshot
        app.typeKey("g", modifierFlags: [.command])
        let updatedStatusField = app.textFields["FindInPageController.statusField"]
        let updatedStatusFieldTextContent = updatedStatusField.value as! String
        XCTAssertTrue(
            updatedStatusField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Couldn't find the updated \"Find in Page\" statusField in a reasonable timeframe."
        )

        XCTAssertEqual(updatedStatusFieldTextContent, "2 of 4", "Unexpected status field text content after a \"Find Next\" operation.")
        let findNextScreenshot = loremIpsumWebView.screenshot()
        let highlightedPixelsInFindNextScreenshot = try XCTUnwrap(findNextScreenshot.image.matchingPixels(of: .findHighlightColor))
        let findNextHighlightPoints = highlightedPixelsInFindNextScreenshot.map { $0.point }
        let pixelSetIntersection = findHighlightPoints
            .intersection(findNextHighlightPoints) // If the highlighted text has moved as expected, this should not have many elements

        XCTAssertGreaterThan(
            highlightedPixelsInFindNextScreenshot.count,
            minimumExpectedMatchingPixelsInFindHighlight,
            "There are expected to be more than \(minimumExpectedMatchingPixelsInFindHighlight) pixels of NSColor.findHighlightColor in a screenshot of a \"Find in Page\" search where there is a match, but this test found \(highlightedPixelsInFindNextScreenshot) matching pixels."
        )
        XCTAssertTrue(
            pixelSetIntersection.count <= findNextHighlightPoints.count / 2,
            "When the selection rectangle has moved as expected, fewer than half of the highlighted pixel coordinates from \"Find Next\" should intersect with the highlighted pixel coordinates from the initial \"Find\" operation."
        )
    }
}

/// Helpers for the Find in Page tests
private extension FindInPageTests {
    /// A shared URL to reference the local HTML file
    class var loremIpsumFileURL: URL {
        let loremIpsumFileName = "lorem_ipsum.html"
        XCTAssertNotNil(
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            "It wasn't possible to obtain a local file URL for the sandbox Documents directory."
        )
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let loremIpsumHTMLFileURL = documentsDirectory.appendingPathComponent(loremIpsumFileName)
        return loremIpsumHTMLFileURL
    }

    /// Save a local HTML file for testing find behavor against
    class func saveLocalHTML() {
        let loremIpsumHTML = """
        <html><head>
        <title>Lorem Ipsum</title></head><body><table><tr><td><p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi ac sem nisi. Cras fermentum mi vitae turpis efficitur malesuada. Donec eget maxima ligula, et tincidunt sapien. Suspendisse posuere diam maxima, dignissim ex at, fringilla elit. Maecenas enim tellus, ornare non pretium a, sodales nec lectus. Vestibulum quis augue orci. Donec eget mi sed magna consequat auctor a a nulla. Etiam condimentum, neque at congue semper, arcu sem commodo tellus, venenatis finibus ex magna vitae erat. Nunc non enim sit amet mi posuere egestas. Donec nibh nisl, pretium sit amet aliquet, porta id nibh. Pellentesque ullamcorper mauris quam, semper hendrerit mi dictum non. Nullam pulvinar, nulla a maximus egestas, velit mi volutpat neque, vitae placerat eros sapien vitae tellus. Pellentesque malesuada accumsan dolor, ut feugiat enim. Curabitur nunc quam, maximus venenatis augue vel, accumsan eros.</p>

        <p>Donec consequat ultrices ante non maximus. Quisque eu semper diam. Nunc ullamcorper eget ex id luctus. Duis metus ex, dapibus sit amet vehicula eget, rhoncus eget lacus. Nulla maximus quis turpis vel pulvinar. Duis neque ligula, tristique et diam ut, fringilla sagittis arcu. Vestibulum suscipit semper lectus, quis placerat ex euismod eu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae;</p>

        <p>Maecenas odio orci, eleifend et ipsum nec, interdum dictum turpis. Nunc nec velit diam. Sed nisl risus, imperdiet sit amet tempor ut, laoreet sed lorem. Aenean egestas ullamcorper sem. Sed accumsan vehicula augue, vitae tempor augue tincidunt id. Morbi ullamcorper posuere lacus id tempus. Ut vel tincidunt quam, quis consectetur velit. Mauris id lorem vitae odio consectetur vehicula. Vestibulum viverra scelerisque porta. Vestibulum eu consequat urna. Etiam dignissim ullamcorper faucibus.</p></td></tr></table></body></html>
        """
        let loremIpsumData = Data(loremIpsumHTML.utf8)

        do {
            try loremIpsumData.write(to: loremIpsumFileURL, options: [])
        } catch {
            XCTFail("It wasn't possible to write out the required local HTML file for the tests: \(error.localizedDescription)")
        }
    }

    /// Remove it when done
    class func removeLocalHTML() {
        do {
            try FileManager.default.removeItem(at: loremIpsumFileURL)
        } catch {
            XCTFail("It wasn't possible to remove the required local HTML file for the tests: \(error.localizedDescription)")
        }
    }
}

private extension UInt8 {
    func isCloseTo(_ colorValue: UInt8) -> Bool {
        // Overflow-safe creation of range +/- 1 around value
        let lowerBound: UInt8 = self != 0 ? self &- 1 : 0
        let upperBound: UInt8 = self != 255 ? self &+ 1 : 255

        switch colorValue {
        case lowerBound ... upperBound:
            return true
        default:
            return false
        }
    }
}

private extension NSImage {
    /// Find matching pixels in an NSImage for a specific NSColor
    /// - Parameter colorToMatch: the NSColor to match
    /// - Returns: An array of Pixel structs
    func matchingPixels(of colorToMatch: NSColor) throws -> [Pixel] {
        let cgImage = try XCTUnwrap(
            cgImage(forProposedRect: nil, context: nil, hints: nil),
            "It wasn't possible to obtain the CGImage of the NSImage."
        )
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let colorSpace = bitmap.colorSpace
        let colorToMatchWithColorSpace = try XCTUnwrap(
            colorToMatch.usingColorSpace(colorSpace),
            "It wasn't possible to get the color to match in the local colorspace."
        ) // Compare the color we want to look for in the image after it is in the same colorspace as the image

        var bitmapData: UnsafeMutablePointer<UInt8> = try XCTUnwrap(bitmap.bitmapData, "It wasn't possible to obtain the bitmapData of the bitmap.")
        var redInImage, greenInImage, blueInImage, alphaInImage: UInt8

        let redToMatch = UInt8(colorToMatchWithColorSpace.redComponent * 255.999999) // color components in 0-255 values in this colorspace
        let greenToMatch = UInt8(colorToMatchWithColorSpace.greenComponent * 255.999999)
        let blueToMatch = UInt8(colorToMatchWithColorSpace.blueComponent * 255.999999)

        var pixels: [Pixel] = []

        for yPoint in 0 ..< bitmap.pixelsHigh {
            for xPoint in 0 ..< bitmap.pixelsWide {
                redInImage = bitmapData.pointee
                bitmapData = bitmapData.advanced(by: 1)
                greenInImage = bitmapData.pointee
                bitmapData = bitmapData.advanced(by: 1)
                blueInImage = bitmapData.pointee
                bitmapData = bitmapData.advanced(by: 1)
                alphaInImage = bitmapData.pointee
                bitmapData = bitmapData.advanced(by: 1)
                if redInImage.isCloseTo(redToMatch), greenInImage.isCloseTo(greenToMatch),
                   blueInImage.isCloseTo(blueToMatch)
                { // We aren't matching alpha
                    pixels.append(Pixel(
                        red: redInImage,
                        green: greenInImage,
                        blue: blueInImage,
                        alpha: alphaInImage,
                        point: CGPoint(x: xPoint, y: yPoint)
                    ))
                }
            }
        }
        return pixels
    }
}

/// A struct of pixel color and coordinate values in 0-255 color values
private struct Pixel: Hashable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var alpha: UInt8
    var point: CGPoint
}

extension CGPoint: Hashable {
    /// So we can do set operations with sets of CGPoints
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}
