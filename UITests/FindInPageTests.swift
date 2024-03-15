//
//	FindInPageTests.swift
//
//	Copyright © 2024 DuckDuckGo. All rights reserved.
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.
//

import XCTest

class FindInPageTests: XCTestCase {
	let app = XCUIApplication()
	let timeout = 0.3
	let addressBarTextField = XCUIApplication().windows.textFields["AddressBarViewController.addressBarTextField"]
	let loremIpsumWebView = XCUIApplication().windows.webViews["Lorem Ipsum"]
	let findInPageCloseButton = XCUIApplication().windows.buttons["FindInPageController.closeButton"]

	override class func setUp() {
		saveLocalHTML()
	}

	override class func tearDown() {
		removeLocalHTML()
	}

	override func setUpWithError() throws {
		continueAfterFailure = false
		app.launch()
		app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
		app.typeKey("n", modifierFlags: .command)
	}

	func test_findInPage_canBeOpenedWithKeyCommand() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")

		app.typeKey("f", modifierFlags: .command)

		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")
	}

	func test_findInPage_canBeOpenedWithMenuBarItem() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		let findInPageMenuBarItem = app.menuItems["MainMenu.findInPage"]
		XCTAssertTrue(findInPageMenuBarItem.waitForExistence(timeout: timeout), "Couldn't find \"Find in Page\" main menu bar item in a reasonable timeframe.")

		findInPageMenuBarItem.click()

		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" via the menu items Edit->Find->\"Find in Page\", the elements of the \"Find in Page\" interface should exist.")
	}

	func test_findInPage_canBeOpenedWithMoreOptionsMenuItem() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		let optionsButton = app.windows.buttons["NavigationBarViewController.optionsButton"]
		XCTAssertTrue(optionsButton.waitForExistence(timeout: timeout), "Couldn't find options item in a reasonable timeframe.")
		optionsButton.click()

		let findInPageMoreOptionsMenuItem = app.menuItems["MoreOptionsMenu.findInPage"]
		XCTAssertTrue(findInPageMoreOptionsMenuItem.waitForExistence(timeout: timeout), "Couldn't find More Options \"Find in Page\" menu item in a reasonable timeframe.")
		findInPageMoreOptionsMenuItem.click()

		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" via the More Options \"Find in Page\" menu item, the elements of the \"Find in Page\" interface should exist.")
	}

	func test_findInPage_canBeClosedWithEscape() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		app.typeKey("f", modifierFlags: .command)
		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")

		app.typeKey(.escape, modifierFlags: [])

		XCTAssertTrue(findInPageCloseButton.waitForNonExistence(timeout: timeout), "After closing \"Find in Page\" with escape, the elements of the \"Find in Page\" interface should no longer exist.")
	}

	func test_findInPage_canBeClosedWithShiftCommandF() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		app.typeKey("f", modifierFlags: .command)
		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")

		app.typeKey("f", modifierFlags: [.command, .shift])

		XCTAssertTrue(findInPageCloseButton.waitForNonExistence(timeout: timeout), "After closing \"Find in Page\" with escape, the elements of the \"Find in Page\" interface should no longer exist.")
	}

	func test_findInPage_canBeClosedWithHideFindMenuItem() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		app.typeKey("f", modifierFlags: .command)
		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")

		let findInPageDoneMenuBarItem = app.menuItems["MainMenu.findInPageDone"]
		XCTAssertTrue(findInPageDoneMenuBarItem.waitForExistence(timeout: timeout), "Couldn't find \"Find in Page\" done main menu item in a reasonable timeframe.")
		findInPageDoneMenuBarItem.click()

		XCTAssertTrue(findInPageCloseButton.waitForNonExistence(timeout: timeout), "After closing \"Find in Page\" with escape, the elements of the \"Find in Page\" interface should no longer exist.")
	}

	func test_findInPage_showsCorrectNumberOfOccurences() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		app.typeKey("f", modifierFlags: .command)
		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")

		app.typeText("maximus\r")
		let statusField = app.textFields["FindInPageController.statusField"]
		XCTAssertTrue(statusField.waitForExistence(timeout: timeout), "Couldn't find \"Find in Page\" statusField in a reasonable timeframe.")
		XCTAssertNotNil(statusField.value as? String, "There was no string content in the \"Find in Page\" status field when it was expected.")
		let statusFieldTextContent = statusField.value as! String

		XCTAssertEqual(statusFieldTextContent, "1 of 4") // Note: this is not a localized test element, and it should have a localization strategy.
	}

	func test_findInPage_findNextGoesToNextOccurrence() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		app.typeKey("f", modifierFlags: .command)
		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")

		app.typeText("maximus\r")
		let statusField = app.textFields["FindInPageController.statusField"]
		XCTAssertTrue(statusField.waitForExistence(timeout: timeout), "Couldn't find \"Find in Page\" statusField in a reasonable timeframe.")
		XCTAssertNotNil(statusField.value as? String, "There was no string content in the \"Find in Page\" status field when it was expected.")
		let statusFieldTextContent = statusField.value as! String

		XCTAssertEqual(statusFieldTextContent, "1 of 4") // Note: this is not a localized test element, and it should have a localization strategy.

		let findInPageScreenshot = loremIpsumWebView.screenshot()

		let findNextMenuBarItem = app.menuItems["MainMenu.findNext"]
		XCTAssertTrue(findNextMenuBarItem.waitForExistence(timeout: timeout), "Couldn't find \"Find Next\" main menu bar item in a reasonable timeframe.")

		findNextMenuBarItem.click()
		let updatedStatusField = app.textFields["FindInPageController.statusField"]
		let updatedStatusFieldTextContent = updatedStatusField.value as! String
		XCTAssertTrue(updatedStatusField.waitForExistence(timeout: timeout), "Couldn't find the updated \"Find in Page\" statusField in a reasonable timeframe.")
		XCTAssertEqual(updatedStatusFieldTextContent, "2 of 4") // Note: this is not a localized test element, and it should have a localization strategy.
		let findNextScreenshot = loremIpsumWebView.screenshot()

		XCTAssertNotEqual(findInPageScreenshot.pngRepresentation, findNextScreenshot.pngRepresentation) // A screenshot of the find results and the find next results should be different
		let count = findNextScreenshot.image.numberOfMatchingPixels(of: .findHighlightColor)
		let expectedNumberOfMatchingPixels = 150
		XCTAssertGreaterThan(count, expectedNumberOfMatchingPixels, "Although the highlight color was detected, there are expected to be more than \(expectedNumberOfMatchingPixels) pixels of NSColor.findHighlightColor in a screenshot of a \"Find in Page\" search where there is a match, and the page text and background is black, and this test only found \(count) matching pixels.")
	}

	func test_findInPage_findNextNextArrowGoesToNextOccurrence() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		app.typeKey("f", modifierFlags: .command)
		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")

		app.typeText("maximus\r")
		let statusField = app.textFields["FindInPageController.statusField"]
		XCTAssertTrue(statusField.waitForExistence(timeout: timeout), "Couldn't find \"Find in Page\" statusField in a reasonable timeframe.")
		XCTAssertNotNil(statusField.value as? String, "There was no string content in the \"Find in Page\" status field when it was expected.")
		let statusFieldTextContent = statusField.value as! String

		XCTAssertEqual(statusFieldTextContent, "1 of 4") // Note: this is not a localized test element, and it should have a localization strategy.

		let findInPageScreenshot = loremIpsumWebView.screenshot()

		let findInPageNextButton = XCUIApplication().windows.buttons["FindInPageController.nextButton"]
		XCTAssertTrue(findInPageNextButton.waitForExistence(timeout: timeout), "Couldn't find \"Find Next\" main menu bar item in a reasonable timeframe.")

		findInPageNextButton.click()
		let updatedStatusField = app.textFields["FindInPageController.statusField"]
		let updatedStatusFieldTextContent = updatedStatusField.value as! String
		XCTAssertTrue(updatedStatusField.waitForExistence(timeout: timeout), "Couldn't find the updated \"Find in Page\" statusField in a reasonable timeframe.")
		XCTAssertEqual(updatedStatusFieldTextContent, "2 of 4") // Note: this is not a localized test element, and it should have a localization strategy.
		let findNextScreenshot = loremIpsumWebView.screenshot()

		XCTAssertNotEqual(findInPageScreenshot.pngRepresentation, findNextScreenshot.pngRepresentation) // A screenshot of the find results and the find next results should be different
		let count = findNextScreenshot.image.numberOfMatchingPixels(of: .findHighlightColor)
		let expectedNumberOfMatchingPixels = 150
		XCTAssertGreaterThan(count, expectedNumberOfMatchingPixels, "Although the highlight color was detected, there are expected to be more than \(expectedNumberOfMatchingPixels) pixels of NSColor.findHighlightColor in a screenshot of a \"Find in Page\" search where there is a match, and the page text and background is black, and this test only found \(count) matching pixels.")
	}

	func test_findInPage_commandGGoesToNextOccurrence() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		app.typeKey("f", modifierFlags: .command)
		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")

		app.typeText("maximus\r")
		let statusField = app.textFields["FindInPageController.statusField"]
		XCTAssertTrue(statusField.waitForExistence(timeout: timeout), "Couldn't find \"Find in Page\" statusField in a reasonable timeframe.")
		XCTAssertNotNil(statusField.value as? String, "There was no string content in the \"Find in Page\" status field when it was expected.")
		let statusFieldTextContent = statusField.value as! String

		XCTAssertEqual(statusFieldTextContent, "1 of 4") // Note: this is not a localized test element, and it should have a localization strategy.

		let findInPageScreenshot = loremIpsumWebView.screenshot()

		app.typeKey("g", modifierFlags: [.command])
		let updatedStatusField = app.textFields["FindInPageController.statusField"]
		let updatedStatusFieldTextContent = updatedStatusField.value as! String
		XCTAssertTrue(updatedStatusField.waitForExistence(timeout: timeout), "Couldn't find the updated \"Find in Page\" statusField in a reasonable timeframe.")
		XCTAssertEqual(updatedStatusFieldTextContent, "2 of 4") // Note: this is not a localized test element, and it should have a localization strategy.
		let findNextScreenshot = loremIpsumWebView.screenshot()

		XCTAssertNotEqual(findInPageScreenshot.pngRepresentation, findNextScreenshot.pngRepresentation) // A screenshot of the find results and the find next results should be different
		let count = findNextScreenshot.image.numberOfMatchingPixels(of: .findHighlightColor)
		let expectedNumberOfMatchingPixels = 150
		XCTAssertGreaterThan(count, expectedNumberOfMatchingPixels, "Although the highlight color was detected, there are expected to be more than \(expectedNumberOfMatchingPixels) pixels of NSColor.findHighlightColor in a screenshot of a \"Find in Page\" search where there is a match, and the page text and background is black, and this test only found \(count) matching pixels.")
	}

	func test_findInPage_showsFocusAndOccurrenceHighlighting() throws {
		XCTAssertTrue(addressBarTextField.waitForExistence(timeout: timeout), "The Address Bar text field does not exist when it is expected.")
		addressBarTextField.typeText("\(FindInPageTests.loremIpsumFileURL().absoluteString)\r")
		XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: timeout), "Local \"Lorem Ipsum\" web page didn't load with the expected title in a reasonable timeframe.")
		app.typeKey("f", modifierFlags: .command)
		XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: timeout), "After invoking \"Find in Page\" with command-f, the elements of the \"Find in Page\" interface should exist.")
		app.typeText("maximus\r")
		let statusField = app.textFields["FindInPageController.statusField"]
		XCTAssertTrue(statusField.waitForExistence(timeout: timeout), "Couldn't find \"Find in Page\" statusField in a reasonable timeframe.")
		XCTAssertNotNil(statusField.value as? String, "There was no string content in the \"Find in Page\" status field when it was expected.")
		let statusFieldTextContent = statusField.value as! String
		XCTAssertEqual(statusFieldTextContent, "1 of 4", "Test cannot continue because there was an unexpected number of matches for a \"Find in Page\" operation.") // Note: this is not a localized test element, and it should have a localization strategy.

		let webViewWithSelectedWordsScreenshot = loremIpsumWebView.screenshot()
		let count = webViewWithSelectedWordsScreenshot.image.numberOfMatchingPixels(of: .findHighlightColor)
		let expectedNumberOfMatchingPixels = 150
		XCTAssertGreaterThan(count, expectedNumberOfMatchingPixels, "Although the highlight color was detected, there are expected to be more than \(expectedNumberOfMatchingPixels) pixels of NSColor.findHighlightColor in a screenshot of a \"Find in Page\" search where there is a match, and the page text and background is black, and this test only found \(count) matching pixels.")
	}
}

extension FindInPageTests {
	class func loremIpsumFileURL() -> URL {
		let loremIpsumFileName = "lorem_ipsum.html"
		XCTAssertNotNil(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, "It wasn't possible to obtain a local file URL for the sandbox Documents directory.")
		let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let loremIpsumHTMLFileURL = documentsDirectory.appendingPathComponent(loremIpsumFileName)
		return loremIpsumHTMLFileURL
	}

	class func saveLocalHTML() {
		let loremIpsumHTML = """
		<html><head><style>
		body {
		  background-color: black;
		  color: black;
		}
		</style>
		<title>Lorem Ipsum</title></head><body><table><tr><td><p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi ac sem nisi. Cras fermentum mi vitae turpis efficitur malesuada. Donec eget maxima ligula, et tincidunt sapien. Suspendisse posuere diam maxima, dignissim ex at, fringilla elit. Maecenas enim tellus, ornare non pretium a, sodales nec lectus. Vestibulum quis augue orci. Donec eget mi sed magna consequat auctor a a nulla. Etiam condimentum, neque at congue semper, arcu sem commodo tellus, venenatis finibus ex magna vitae erat. Nunc non enim sit amet mi posuere egestas. Donec nibh nisl, pretium sit amet aliquet, porta id nibh. Pellentesque ullamcorper mauris quam, semper hendrerit mi dictum non. Nullam pulvinar, nulla a maximus egestas, velit mi volutpat neque, vitae placerat eros sapien vitae tellus. Pellentesque malesuada accumsan dolor, ut feugiat enim. Curabitur nunc quam, maximus venenatis augue vel, accumsan eros.</p>

		<p>Donec consequat ultrices ante non maximus. Quisque eu semper diam. Nunc ullamcorper eget ex id luctus. Duis metus ex, dapibus sit amet vehicula eget, rhoncus eget lacus. Nulla maximus quis turpis vel pulvinar. Duis neque ligula, tristique et diam ut, fringilla sagittis arcu. Vestibulum suscipit semper lectus, quis placerat ex euismod eu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae;</p>

		<p>Maecenas odio orci, eleifend et ipsum nec, interdum dictum turpis. Nunc nec velit diam. Sed nisl risus, imperdiet sit amet tempor ut, laoreet sed lorem. Aenean egestas ullamcorper sem. Sed accumsan vehicula augue, vitae tempor augue tincidunt id. Morbi ullamcorper posuere lacus id tempus. Ut vel tincidunt quam, quis consectetur velit. Mauris id lorem vitae odio consectetur vehicula. Vestibulum viverra scelerisque porta. Vestibulum eu consequat urna. Etiam dignissim ullamcorper faucibus.</p></td></tr></table></body></html>
		"""
		let loremIpsumData = Data(loremIpsumHTML.utf8)

		do {
			try loremIpsumData.write(to: loremIpsumFileURL(), options: [])
		} catch {
			XCTFail("It wasn't possible to write out the required local HTML file for the tests: \(error.localizedDescription)")
		}
	}

	class func removeLocalHTML() {
		do {
			try FileManager.default.removeItem(at: loremIpsumFileURL())
		} catch {
			XCTFail("It wasn't possible to remove the required local HTML file for the tests: \(error.localizedDescription)")
		}
	}
}

extension NSImage {

	func numberOfMatchingPixels(of colorToMatch: NSColor) -> Int {
		let imageNoAlpha =	self.withNoAlphaChannel() // We remove the alpha, since this is for screenshot comparisons
		XCTAssertNotNil(imageNoAlpha, "It wasn't possible to remove the alpha channel of the image when it was expected.")
		let pixelData = imageNoAlpha!.pixels().pixelArray // Pixels of the image we will check for the requested color
		let colorSpace = imageNoAlpha!.pixels().colorSpace // We have to check in the same colorspace of the image
		XCTAssertNotNil(colorToMatch.usingColorSpace(colorSpace), "It wasn't possible to get the local colorspace for the UI Tests when this is expected.")
		let colorToMatchWithColorSpace = colorToMatch.usingColorSpace(colorSpace)! // And this is the same color converted to the image's colorspace, so we can compare
		let colorToMatchRed = UInt8(colorToMatchWithColorSpace.redComponent * 255.999999) // color components in 0-255 values in this colorspace
		let colorToMatchGreen = UInt8(colorToMatchWithColorSpace.greenComponent * 255.999999)
		let colorToMatchBlue = UInt8(colorToMatchWithColorSpace.blueComponent * 255.999999)
		let pixelSet = Set(pixelData) // A set of the pixels so we do our first check for existence of the color without enumerating a very large array
		var matchingPixels: [Pixel: Int] = [:]
		if pixelSet.contains(Pixel(red: colorToMatchRed, green: colorToMatchGreen, blue: colorToMatchBlue, alpha: 255)) { // If there is a match in the set
			pixelData.forEach { matchingPixels[$0, default: 0] += 1 } // Get all the matches in the array
		} else {
			return 0
		}
		return matchingPixels.count
	}

	func pixels() -> (pixelArray: [Pixel], colorSpace: NSColorSpace) {
		let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
		let bitmap = NSBitmapImageRep(cgImage: cgImage!)
		let colorSpace = bitmap.colorSpace
		var bitmapData: UnsafeMutablePointer<UInt8> = bitmap.bitmapData!
		var red, green, blue, alpha: UInt8
		var pixels: [Pixel] = []

		for _ in 0..<bitmap.pixelsHigh {
			for _ in 0..<bitmap.pixelsWide {
				red = bitmapData.pointee
				bitmapData = bitmapData.advanced(by: 1)
				green = bitmapData.pointee
				bitmapData = bitmapData.advanced(by: 1)
				blue = bitmapData.pointee
				bitmapData = bitmapData.advanced(by: 1)
				alpha = bitmapData.pointee

				bitmapData = bitmapData.advanced(by: 1)
				pixels.append(Pixel(red: red, green: green, blue: blue, alpha: alpha))
			}
		}

		return (pixelArray: pixels, colorSpace: colorSpace)
	}

	func withNoAlphaChannel() -> NSImage? {
		guard let cgImageWithPossibleAlpha = cgImage(forProposedRect: nil, context: nil, hints: nil),
		      let colorSpace = cgImageWithPossibleAlpha.colorSpace,
		      let context = CGContext(data: nil, width: cgImageWithPossibleAlpha.width,
									  height: cgImageWithPossibleAlpha.height,
									  bitsPerComponent: cgImageWithPossibleAlpha.bitsPerComponent,
									  bytesPerRow: cgImageWithPossibleAlpha.bytesPerRow,
									  space: colorSpace,
									  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) // Remove alpha
		else {
			return nil
		}

		context.draw(cgImageWithPossibleAlpha, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))

		guard let cgImageWithoutAlpha = context.makeImage() else {
			return nil
		}

		return NSImage(cgImage: cgImageWithoutAlpha, size: .zero)
	}
}

struct Pixel: Hashable {
	var red: UInt8
	var green: UInt8
	var blue: UInt8
	var alpha: UInt8
}
