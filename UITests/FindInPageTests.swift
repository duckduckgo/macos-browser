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

extension FindInPageTests {
    func loremIpsumFileURL() -> URL {
        let loremIpsumFileName = "lorem_ipsum.html"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let loremIpsumHTMLFileURL = documentsDirectory.appendingPathComponent(loremIpsumFileName)
        return loremIpsumHTMLFileURL
    }

    func saveLocalHTML() {
        let loremIpsumHTML = """
        <html><head><title>Lorem Ipsum</title></head><body><table><tr><td><p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi ac sem nisi. Cras fermentum mi vitae turpis efficitur malesuada. Donec eget maximus ligula, et tincidunt sapien. Suspendisse posuere diam maximus, dignissim ex at, fringilla elit. Maecenas enim tellus, ornare non pretium a, sodales nec lectus. Vestibulum quis augue orci. Donec eget mi sed magna consequat auctor a a nulla. Etiam condimentum, neque at congue semper, arcu sem commodo tellus, venenatis finibus ex magna vitae erat. Nunc non enim sit amet mi posuere egestas. Donec nibh nisl, pretium sit amet molestie aliquet, porta id nibh. Pellentesque ullamcorper mauris quam, semper hendrerit mi dictum non. Nullam pulvinar, nulla a maximus egestas, velit mi volutpat neque, vitae placerat eros sapien vitae tellus. Pellentesque malesuada accumsan dolor, ut feugiat enim. Curabitur nunc quam, maximus venenatis augue vel, molestie accumsan eros.</p>

                                <p>Donec consequat ultrices ante non maximus. Quisque eu semper diam. Nunc ullamcorper eget ex id luctus. Duis metus ex, dapibus sit amet vehicula eget, rhoncus eget lacus. Nulla maximus quis turpis vel pulvinar. Duis neque ligula, tristique et diam ut, fringilla sagittis arcu. Vestibulum suscipit semper lectus, quis placerat ex euismod eu. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae;</p>

                                <p>Maecenas odio orci, eleifend et ipsum nec, interdum dictum turpis. Nunc nec velit diam. Sed nisl risus, imperdiet sit amet tempor ut, laoreet sed lorem. Aenean egestas ullamcorper sem. Sed accumsan vehicula augue, vitae tempor augue tincidunt id. Morbi ullamcorper posuere lacus id tempus. Ut vel tincidunt quam, quis consectetur velit. Mauris id lore
        m vitae odio consectetur vehicula. Vestibulum viverra scelerisque porta. Vestibulum eu consequat urna. Etiam dignissim ullamcorper faucibus.</p></td></tr></table></body></html>
        """
        let loremIpsumData = Data(loremIpsumHTML.utf8)

        do {
            try loremIpsumData.write(to: loremIpsumFileURL(), options: [.atomic, .completeFileProtection])
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

class FindInPageTests: XCTestCase {
    let app = XCUIApplication()
    override class func setUp() {
        // This is the setUp() class method.
        // XCTest calls it before calling the first test method.
        // Set up any overall initial state here.
    }

    override func setUp() async throws {
        // This is the setUp() async instance method.
        // XCTest calls it before each test method.
        // Perform any asynchronous setup in this method.
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        app.launch()
        // This is the setUpWithError() instance method.
        // XCTest calls it before each test method.
        // Set up any synchronous per-test state that might throw errors here.
    }

    override func setUp() {
        // This is the setUp() instance method.
        // XCTest calls it before each test method.
        // Set up any synchronous per-test state here.
    }

    override class func tearDown() {
        // This is the tearDown() class method.
        // XCTest calls it after the last test method completes.
        // Perform any overall cleanup here.
    }

    override func tearDown() {
        // This is the tearDown() instance method.
        // XCTest calls it after each test method.
        // Perform any synchronous per-test cleanup here.
    }

    override func tearDownWithError() throws {
        // This is the tearDownWithError() instance method.
        // XCTest calls it after each test method.
        // Perform any synchronous per-test cleanup that might throw errors here.
    }

    override func tearDown() async throws {
        // This is the tearDown() async instance method.
        // XCTest calls it after each test method.
        // Perform any asynchronous per-test cleanup here.
    }

    func test_findInPage_canBeOpenedWithKeyCommand() throws {
        saveLocalHTML()
        let searchOrEnterAddressTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: 1), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        let loremIpsumWebView = XCUIApplication().windows.webViews["Lorem Ipsum"]
        XCTAssertTrue(loremIpsumWebView.waitForExistence(timeout: 1), "Local lorem ipsum web page didn't load with the expected title in a reasonable timeframe.")
        
        app.typeKey("f", modifierFlags: .command)
        let findInPageCloseButton = XCUIApplication().windows.buttons["FindInPageController.closeButton"]
        
        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: 1), "After invoking find in page with command-f, the elements of the find in page interface should exist.")
        removeLocalHTML()
    }

    func test_findInPage_canBeOpenedWithMenuItem() throws {
        saveLocalHTML()
        let searchOrEnterAddressTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        XCTAssertTrue(searchOrEnterAddressTextField.waitForExistence(timeout: 1), "Address bar text field does not exist when it is expected to exist")
        searchOrEnterAddressTextField.typeText("\(loremIpsumFileURL().absoluteString)\r")
        let loremIpsumWebView = XCUIApplication().windows.webViews["Lorem Ipsum"]
        let findInPageMenuBarItem = app.menuItems["MainViewController.findInPage"]
        XCTAssertTrue(findInPageMenuBarItem.waitForExistence(timeout: 1), "Couldn't find Find in Page menu bar item in a reasonable timeframe.")
        
        findInPageMenuBarItem.click()
        let findInPageCloseButton = XCUIApplication().windows.buttons["FindInPageController.closeButton"]
        
        XCTAssertTrue(findInPageCloseButton.waitForExistence(timeout: 1), "After invoking find in page via the menu items Edit->Find->Find in Page, the elements of the find in page interface should exist.")
        removeLocalHTML()
    }
}
