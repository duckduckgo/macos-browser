//
//  PermissionsTests.swift
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

/// We are apparently in the part of the `XCUIAutomation` life cycle right now in which interruption management using `addUIInterruptionMonitor`
/// doesn't fire due to an acknowledged bug (https://forums.developer.apple.com/forums/thread/737880), so we can't test these the best way, which is
/// to create an interruption handler and wait for TCC requests to respond to (https://eclecticlight.co/2023/02/10/privacy-what-tcc-does-and-doesnt/).
/// Realistically, the best approach (in terms of robust test design) may never be a good fit for these tests, because it is always a possibility that
/// one of the targeted macOS versions is manifesting this every-few-systems bug. Therefore, these tests simply wait for the relevant
/// privacy request to click on directly, via a combination of bundle ID targeting and button targeting by number. That means that adjustments could
/// be needed in the future, in case of significant changes in this system-level interface in future macOS versions (but Apple tries not to change
/// that too frequently) or its backend (for instance, if the bundle ID for the user notification center changes). Here is a link to how to do this
/// the best way, in the event that a future macOS version stops supporting this approach, but also solves the bug with `addUIInterruptionMonitor`,
/// and you want to branch the implementations per macOS version:
/// https://stackoverflow.com/questions/56559269/adduiinterruptionmonitor-is-not-getting-called-on-macos
class PermissionsTests: UITestCase {
    private var app: XCUIApplication!
    private var notificationCenter: XCUIApplication!
    private var addressBarTextField: XCUIElement!
    private var permissionsSiteURL: URL!
    private var historyMenuBarItem: XCUIElement!
    private var clearAllHistoryMenuItem: XCUIElement!
    private var clearAllHistoryAlertClearButton: XCUIElement!
    private var fakeFireButton: XCUIElement!

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"

        permissionsSiteURL = try XCTUnwrap(URL(string: "https://permission.site"), "It wasn't possible to unwrap a URL that the tests depend on.")
        notificationCenter = XCUIApplication(bundleIdentifier: "com.apple.UserNotificationCenter")
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        historyMenuBarItem = app.menuBarItems["History"]
        clearAllHistoryMenuItem = app.menuItems["HistoryMenu.clearAllHistory"]
        clearAllHistoryAlertClearButton = app.buttons["ClearAllHistoryAndDataAlert.clearButton"]
        fakeFireButton = app.buttons["FireViewController.fakeFireButton"]

        app.resetAuthorizationStatus(for: .camera) // These resets work much better before launch.
        app.resetAuthorizationStatus(for: .microphone)

        app.launch()
        app.activate()
        historyMenuBarItem.clickAfterExistenceTestSucceeds()
        clearAllHistoryMenuItem.clickAfterExistenceTestSucceeds()
        clearAllHistoryAlertClearButton.clickAfterExistenceTestSucceeds() // Manually remove the history
        XCTAssertTrue( // Let any ongoing fire animation or data processes complete
            fakeFireButton.waitForNonExistence(timeout: UITests.Timeouts.fireAnimation),
            "Fire animation didn't finish and cease existing in a reasonable timeframe."
        )

        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Enforce a single window
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe before starting the test."
        )
    }

    func test_cameraPermissions_withAcceptedTCCChallenge_showCorrectStateInBrowser() throws {
        addressBarTextField.typeURLAfterExistenceTestSucceeds(permissionsSiteURL)

        let cameraButton = app.webViews.buttons["Camera"]
        cameraButton.clickAfterExistenceTestSucceeds()
        XCTAssert(
            notificationCenter.buttons.firstMatch.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The notification center didn't appear. This can happen because the TCC setting at the start of the test wasn't correct – check the app.resetPermissions behavior."
        )
        let allowButtonIndex = try XCTUnwrap(notificationCenter.indexOfSystemModelDialogButtonOnElement(
            titled: "Allow",
            "OK"
        )) // You can add any titles you see this permission dialog using on any tested macOS versions, because it is evaluated by a variadic
        // function.
        let allowButton = notificationCenter.buttons.element(boundBy: allowButtonIndex)
        allowButton.clickAfterExistenceTestSucceeds() // Click system camera permissions dialog
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]
        permissionsPopoverAllowButton.clickAfterExistenceTestSucceeds()
        var websitePermissionsColorIsGreen = false
        for _ in 1 ... 4 { // permission.site updates this color a bit slowly and we have no control over it, so we try a few times.
            websitePermissionsColorIsGreen = try websitePermissionsButtonIsExpectedColor(cameraButton, is: .green)
            if websitePermissionsColorIsGreen {
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(
            websitePermissionsColorIsGreen,
            "After a few attempts to wait for permissions.site to update their button animation after the TCC dialog, their button has to be green."
        )

        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.cameraPermissionButton"]
        navigationBarViewControllerPermissionButton.clickAfterExistenceTestSucceeds()

        let permissionContextMenuAlwaysAsk = app.menuItems["PermissionContextMenu.alwaysAsk"]
        XCTAssertTrue(
            permissionContextMenuAlwaysAsk.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "permissionContextMenuAlwaysAsk didn't exist in a reasonable timeframe."
        )
        let permissionContextMenuAlwaysAskValue = try XCTUnwrap(permissionContextMenuAlwaysAsk.value as? String)
        XCTAssertEqual(
            permissionContextMenuAlwaysAskValue,
            "selected",
            "The \"always ask\" menu item of the permission context menu has to be the selected item."
        )
    }

    func test_cameraPermissions_withDeniedTCCChallenge_showCorrectStateInBrowser() throws {
        addressBarTextField.typeURLAfterExistenceTestSucceeds(permissionsSiteURL)

        let cameraButton = app.webViews.buttons["Camera"]
        cameraButton.clickAfterExistenceTestSucceeds()
        XCTAssert(
            notificationCenter.buttons.firstMatch.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The notification center didn't appear. This can happen because the TCC setting at the start of the test wasn't correct – check the app.resetPermissions behavior."
        )
        let denyButtonIndex = try XCTUnwrap(notificationCenter.indexOfSystemModelDialogButtonOnElement(
            titled: "Deny", "No", "Cancel", "Don’t Allow", "Don't Allow"
        )) // You can add any titles you see this permission dialog using on any tested macOS versions, because it is evaluated by a variadic
        // function.
        let denyButton = notificationCenter.buttons.element(boundBy: denyButtonIndex)
        denyButton.clickAfterExistenceTestSucceeds() // Click system camera permissions dialog
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]

        XCTAssertTrue( // Prove that the browser's permission popover does not appear
            permissionsPopoverAllowButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The permissions popover in the browser should not appear when camera permission has been denied."
        )

        var websitePermissionsColorIsRed = false
        for _ in 1 ... 4 {
            websitePermissionsColorIsRed = try websitePermissionsButtonIsExpectedColor(cameraButton, is: .red)
            if websitePermissionsColorIsRed {
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(
            websitePermissionsColorIsRed,
            "After a few attempts to wait for permissions.site to update their button animation after the TCC dialog, their button has to be red."
        )

        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.cameraPermissionButton"]
        XCTAssertTrue( // Prove that the browser's permission button does not appear
            navigationBarViewControllerPermissionButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The permissions button in the browser should not appear when camera permission has been denied."
        )
    }

    func test_cameraPermissions_withAcceptedTCCChallenge_whereAlwaysDenyIsSelected_alwaysDenies() throws {
        addressBarTextField.typeURLAfterExistenceTestSucceeds(permissionsSiteURL)

        let cameraButton = app.webViews.buttons["Camera"]
        cameraButton.clickAfterExistenceTestSucceeds()
        XCTAssert(
            notificationCenter.buttons.firstMatch.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The notification center didn't appear. This can happen because the TCC setting at the start of the test wasn't correct – check the app.resetPermissions behavior."
        )
        let allowButtonIndex = try XCTUnwrap(notificationCenter.indexOfSystemModelDialogButtonOnElement(
            titled: "Allow",
            "OK"
        )) // You can add any titles you see this permission dialog using on any tested macOS versions, because it is evaluated by a variadic
        // function.
        let allowButton = notificationCenter.buttons.element(boundBy: allowButtonIndex)
        allowButton.clickAfterExistenceTestSucceeds() // Click system camera permissions dialog
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]
        permissionsPopoverAllowButton.clickAfterExistenceTestSucceeds()
        var websitePermissionsColorIsGreen = false
        for _ in 1 ... 4 { // permission.site updates this color a bit slowly and we have no control over it, so we try a few times.
            websitePermissionsColorIsGreen = try websitePermissionsButtonIsExpectedColor(cameraButton, is: .green)
            if websitePermissionsColorIsGreen {
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(
            websitePermissionsColorIsGreen,
            "After a few attempts to wait for permissions.site to update their button animation after the TCC dialog, their button has to be green."
        )

        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.cameraPermissionButton"]
        navigationBarViewControllerPermissionButton.clickAfterExistenceTestSucceeds()

        let permissionContextMenuAlwaysAsk = app.menuItems["PermissionContextMenu.alwaysAsk"]

        XCTAssertTrue(
            permissionContextMenuAlwaysAsk.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "permissionContextMenuAlwaysAsk didn't exist in a reasonable timeframe."
        )
        let permissionContextMenuAlwaysAskValue = try XCTUnwrap(permissionContextMenuAlwaysAsk.value as? String)
        XCTAssertEqual(
            permissionContextMenuAlwaysAskValue,
            "selected",
            "The \"always ask\" menu item of the permission context menu has to be the selected item."
        )
        let permissionContextMenuAlwaysDeny = app.menuItems["PermissionContextMenu.alwaysDeny"]
        permissionContextMenuAlwaysDeny.clickAfterExistenceTestSucceeds()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Enforce a single window
        app.typeKey("n", modifierFlags: .command)
        addressBarTextField.typeURL(permissionsSiteURL)
        for _ in 1 ... 4 {
            cameraButton.clickAfterExistenceTestSucceeds()
        }
        XCTAssertTrue(
            try websitePermissionsButtonIsExpectedColor(cameraButton, is: .red),
            "Even if we click the button for the denied resource many times, when we are on a site where we have set \"always deny\" for the resource, the permission button will remain red"
        )
        XCTAssert(
            notificationCenter.buttons.firstMatch.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Even if we click the button for the denied resource many times, when we are on a site where we have set \"always deny\" for the resource, the TCC dialog permission alert will not be on the screen"
        )
        XCTAssert(
            permissionsPopoverAllowButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Even if we click the button for the denied resource many times, when we are on a site where we have set \"always deny\" for the resource, the permission popover will not be on the screen"
        )
    }

    func test_microphonePermissions_withAcceptedTCCChallenge_showCorrectStateInBrowser() throws {
        addressBarTextField.typeURLAfterExistenceTestSucceeds(permissionsSiteURL)

        let microphoneButton = app.webViews.buttons["Microphone"]
        microphoneButton.clickAfterExistenceTestSucceeds()
        XCTAssert(
            notificationCenter.buttons.firstMatch.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The notification center didn't appear. This can happen because the TCC setting at the start of the test wasn't correct – check the app.resetPermissions behavior."
        )
        let allowButtonIndex = try XCTUnwrap(notificationCenter.indexOfSystemModelDialogButtonOnElement(
            titled: "Allow",
            "OK"
        )) // You can add any titles you see this permission dialog using on any tested macOS versions, because it is evaluated by a variadic
        // function.
        let allowButton = notificationCenter.buttons.element(boundBy: allowButtonIndex)
        allowButton.clickAfterExistenceTestSucceeds() // Click system microphone permissions dialog
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]
        permissionsPopoverAllowButton.clickAfterExistenceTestSucceeds()
        var websitePermissionsColorIsGreen = false
        for _ in 1 ... 4 { // permission.site updates this color a bit slowly and we have no control over it, so we try a few times.
            websitePermissionsColorIsGreen = try websitePermissionsButtonIsExpectedColor(microphoneButton, is: .green)
            if websitePermissionsColorIsGreen {
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(
            websitePermissionsColorIsGreen,
            "After a few attempts to wait for permissions.site to update their button animation after the TCC dialog, their button has to be green."
        )

        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.microphonePermissionButton"]
        navigationBarViewControllerPermissionButton.clickAfterExistenceTestSucceeds()

        let permissionContextMenuAlwaysAsk = app.menuItems["PermissionContextMenu.alwaysAsk"]
        XCTAssertTrue(
            permissionContextMenuAlwaysAsk.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "permissionContextMenuAlwaysAsk didn't exist in a reasonable timeframe."
        )
        let permissionContextMenuAlwaysAskValue = try XCTUnwrap(permissionContextMenuAlwaysAsk.value as? String)
        XCTAssertEqual(
            permissionContextMenuAlwaysAskValue,
            "selected",
            "The \"always ask\" menu item of the permission context menu has to be the selected item."
        )
    }

    func test_microphonePermissions_withDeniedTCCChallenge_showCorrectStateInBrowser() throws {
        addressBarTextField.typeURLAfterExistenceTestSucceeds(permissionsSiteURL)

        let microphoneButton = app.webViews.buttons["Microphone"]
        microphoneButton.clickAfterExistenceTestSucceeds()
        XCTAssert(
            notificationCenter.buttons.firstMatch.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The notification center didn't appear. This can happen because the TCC setting at the start of the test wasn't correct – check the app.resetPermissions behavior."
        )
        let denyButtonIndex = try XCTUnwrap(notificationCenter.indexOfSystemModelDialogButtonOnElement(
            titled: "Deny", "No", "Cancel", "Don’t Allow", "Don't Allow"
        )) // You can add any titles you see this permission dialog using on any tested macOS versions, because it is evaluated by a variadic
        // function.
        let denyButton = notificationCenter.buttons.element(boundBy: denyButtonIndex)
        denyButton.clickAfterExistenceTestSucceeds() // Click system microphone permissions dialog
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]

        XCTAssertTrue( // Prove that the browser's permission popover does not appear
            permissionsPopoverAllowButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The permissions popover in the browser should not appear when camera permission has been denied."
        )

        var websitePermissionsColorIsRed = false
        for _ in 1 ... 4 {
            websitePermissionsColorIsRed = try websitePermissionsButtonIsExpectedColor(microphoneButton, is: .red)
            if websitePermissionsColorIsRed {
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(
            websitePermissionsColorIsRed,
            "After between one and four attempts to wait for permissions.site to update their button animation after the TCC dialog, their button has to be red."
        )

        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.microphonePermissionButton"]
        XCTAssertTrue( // Prove that the browser's permission button does not appear
            navigationBarViewControllerPermissionButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The permissions button in the browser should not appear when microphone permission has been denied."
        )
    }

    func test_microphonePermissions_withAcceptedTCCChallenge_whereAlwaysDenyIsSelected_alwaysDenies() throws {
        addressBarTextField.typeURLAfterExistenceTestSucceeds(permissionsSiteURL)

        let microphoneButton = app.webViews.buttons["Microphone"]
        microphoneButton.clickAfterExistenceTestSucceeds()
        XCTAssert(
            notificationCenter.buttons.firstMatch.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The notification center didn't appear. This can happen because the TCC setting at the start of the test wasn't correct – check the app.resetPermissions behavior."
        )
        let allowButtonIndex = try XCTUnwrap(notificationCenter.indexOfSystemModelDialogButtonOnElement(
            titled: "Allow",
            "OK"
        )) // You can add any titles you see this permission dialog using on any tested macOS versions, because it is evaluated by a variadic
        // function.
        let allowButton = notificationCenter.buttons.element(boundBy: allowButtonIndex)
        allowButton.clickAfterExistenceTestSucceeds() // Click system microphone permissions dialog
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]
        permissionsPopoverAllowButton.clickAfterExistenceTestSucceeds()
        var websitePermissionsColorIsGreen = false
        for _ in 1 ... 4 { // permission.site updates this color a bit slowly and we have no control over it, so we try a few times.
            websitePermissionsColorIsGreen = try websitePermissionsButtonIsExpectedColor(microphoneButton, is: .green)
            if websitePermissionsColorIsGreen {
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(
            websitePermissionsColorIsGreen,
            "After a few attempts to wait for permissions.site to update their button animation after the TCC dialog, their button has to be green."
        )

        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.microphonePermissionButton"]
        navigationBarViewControllerPermissionButton.clickAfterExistenceTestSucceeds()

        let permissionContextMenuAlwaysAsk = app.menuItems["PermissionContextMenu.alwaysAsk"]
        XCTAssertTrue(
            permissionContextMenuAlwaysAsk.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "permissionContextMenuAlwaysAsk didn't exist in a reasonable timeframe."
        )
        let permissionContextMenuAlwaysAskValue = try XCTUnwrap(permissionContextMenuAlwaysAsk.value as? String)
        XCTAssertEqual(
            permissionContextMenuAlwaysAskValue,
            "selected",
            "The \"always ask\" menu item of the permission context menu has to be the selected item."
        )

        let permissionContextMenuAlwaysDeny = app.menuItems["PermissionContextMenu.alwaysDeny"]
        permissionContextMenuAlwaysDeny.clickAfterExistenceTestSucceeds()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Enforce a single window
        app.typeKey("n", modifierFlags: .command)
        addressBarTextField.typeURL(permissionsSiteURL)
        for _ in 1 ... 4 {
            microphoneButton.clickAfterExistenceTestSucceeds()
        }
        XCTAssertTrue(
            try websitePermissionsButtonIsExpectedColor(microphoneButton, is: .red),
            "Even if we click the button for the denied resource many times, when we are on a site where we have set \"always deny\" for the resource, the permission button will remain red"
        )
        XCTAssert(
            notificationCenter.buttons.firstMatch.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Even if we click the button for the denied resource many times, when we are on a site where we have set \"always deny\" for the resource, the TCC dialog permission alert will not be on the screen"
        )
        XCTAssert(
            permissionsPopoverAllowButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Even if we click the button for the denied resource many times, when we are on a site where we have set \"always deny\" for the resource, the permission popover will not be on the screen"
        )
    }

    func test_locationPermissions_whenAccepted_showCorrectStateInBrowser() throws {
        addressBarTextField.typeURLAfterExistenceTestSucceeds(permissionsSiteURL)

        let locationButton = app.webViews.buttons["Location"]
        locationButton.clickAfterExistenceTestSucceeds()
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]
        permissionsPopoverAllowButton.clickAfterExistenceTestSucceeds()
        var websitePermissionsColorIsGreen = false
        for _ in 1 ... 4 { // permission.site updates this color a bit slowly and we have no control over it, so we try a few times.
            websitePermissionsColorIsGreen = try websitePermissionsButtonIsExpectedColor(locationButton, is: .green)
            if websitePermissionsColorIsGreen {
                break
            }
            usleep(500_000)
        }
        // We would like to be able to test here that the permission.site "Location" button turns green here, but it frequently doesn't turn green
        // when location permissions are granted.

        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.geolocationPermissionButton"]
        navigationBarViewControllerPermissionButton.clickAfterExistenceTestSucceeds()

        let permissionContextMenuAlwaysAsk = app.menuItems["PermissionContextMenu.alwaysAsk"]
        XCTAssertTrue(
            permissionContextMenuAlwaysAsk.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "permissionContextMenuAlwaysAsk didn't exist in a reasonable timeframe."
        )
        let permissionContextMenuAlwaysAskValue = try XCTUnwrap(permissionContextMenuAlwaysAsk.value as? String)
        XCTAssertEqual(
            permissionContextMenuAlwaysAskValue,
            "selected",
            "The \"always ask\" menu item of the permission context menu has to be the selected item."
        )
    }

    func test_locationPermissions_whenAlwaysDenyIsSelected_alwaysDenies() throws {
        addressBarTextField.typeURLAfterExistenceTestSucceeds(permissionsSiteURL)

        let locationButton = app.webViews.buttons["Location"]
        locationButton.clickAfterExistenceTestSucceeds()
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]
        permissionsPopoverAllowButton.clickAfterExistenceTestSucceeds()
        var websitePermissionsColorIsGreen = false
        for _ in 1 ... 4 { // permission.site updates this color a bit slowly and we have no control over it, so we try a few times.
            websitePermissionsColorIsGreen = try websitePermissionsButtonIsExpectedColor(locationButton, is: .green)
            if websitePermissionsColorIsGreen {
                break
            }
            usleep(500_000)
        }

        // We would like to be able to test here that the permission.site "Location" button turns green here, but it frequently doesn't turn green
        // when location permissions are granted.

        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.geolocationPermissionButton"]
        navigationBarViewControllerPermissionButton.clickAfterExistenceTestSucceeds()

        let permissionContextMenuAlwaysAsk = app.menuItems["PermissionContextMenu.alwaysAsk"]
        XCTAssertTrue(
            permissionContextMenuAlwaysAsk.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "permissionContextMenuAlwaysAsk didn't exist in a reasonable timeframe."
        )
        let permissionContextMenuAlwaysAskValue = try XCTUnwrap(permissionContextMenuAlwaysAsk.value as? String)
        XCTAssertEqual(
            permissionContextMenuAlwaysAskValue,
            "selected",
            "The \"always ask\" menu item of the permission context menu has to be the selected item."
        )

        let permissionContextMenuAlwaysDeny = app.menuItems["PermissionContextMenu.alwaysDeny"]
        permissionContextMenuAlwaysDeny.clickAfterExistenceTestSucceeds()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Enforce a single window
        app.typeKey("n", modifierFlags: .command)
        addressBarTextField.typeURL(permissionsSiteURL)
        for _ in 1 ... 4 {
            locationButton.clickAfterExistenceTestSucceeds()
        }
        XCTAssertTrue( // It does turn red when permission is denied.
            try websitePermissionsButtonIsExpectedColor(locationButton, is: .red),
            "Even if we click the button for the denied resource many times, when we are on a site where we have set \"always deny\" for the resource, the permission button will remain red"
        )

        XCTAssert(
            permissionsPopoverAllowButton.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Even if we click the button for the denied resource many times, when we are on a site where we have set \"always deny\" for the resource, the permission popover will not be on the screen"
        )
    }
}

private extension PermissionsTests {
    func websitePermissionsButtonIsExpectedColor(_ button: XCUIElement, is expectedColor: PredominantColor) throws -> Bool {
        let buttonScreenshot = button.screenshot().image
        let trimmedButton = buttonScreenshot.trim(to: CGRect(
            x: 10,
            y: 10,
            width: 20,
            height: 20
        )) // A sample of the button that we are going to analyze for its predominant color tone.
        let predominantColor = try XCTUnwrap(
            trimmedButton.ciImage(with: nil).predominantColor(),
            "It wasn't possible to unwrap the predominant color of the website button screenshot sample"
        )
        return predominantColor == expectedColor
    }
}

private extension XCUIElement {
    /// We don't have as much control over what is going to appear on a modal dialogue, and it feels fragile to use Apple's accessibility IDs since I
    /// don't think there is any contract for that, but we can plan some flexibility in title matching for the button names, since the button names
    /// are in the test description.
    /// - Parameter titled: The title or titles (if they vary across macOS versions) of a button whose index on the element we'd like to know,
    /// variadic
    /// - Returns: An optional Int representing the button index on the element, if a button with this title was found.
    func indexOfSystemModelDialogButtonOnElement(titled: String...) -> Int? {
        for buttonIndex in 0 ... 4 { // It feels unlikely that a system modal dialog will have more than five buttons
            let button = self.buttons.element(boundBy: buttonIndex)
            if button.exists, titled.contains(button.title) {
                return buttonIndex
            }
        }
        return nil
    }
}

/// Understand whether a webpage button is greenish or reddish when we expect one or the other, or states where we need to retry or fail
private enum PredominantColor {
    case red
    case green
    case neither
}

private extension NSImage {
    /// Trim NSImage to sample
    /// - Parameter rect: the sample size to trim to
    /// - Returns: The trimmed NSImage
    func trim(to rect: CGRect) -> NSImage {
        let result = NSImage(size: rect.size)
        result.lockFocus()

        let destRect = CGRect(origin: .zero, size: result.size)
        self.draw(in: destRect, from: rect, operation: .copy, fraction: 1.0)

        result.unlockFocus()
        return result
    }
}

private extension CIImage {
    /// Evaluate a sample of a webpage button to see what its predominant color tone is. Assumes it is being run on a button that is expected to be
    /// either green or red (otherwise we are starting to think into `https://permission.site`'s potential implementation errors or surprise cases,
    /// which I don't think should be part of this test case scope which tests UIs from three responsible organizations in which the tested UIs, in
    /// order of importance, should be: this browser, macOS, permission.site)).
    /// - Returns: .red, .green, .neither if we get a result but it isn't helpful, or nil in the event of an error (but it will always verbosely fail
    /// the test before returning nil, so in practice, if the test is still in progress, it has returned a case.)
    func predominantColor() throws -> PredominantColor? {
        var redValueOfSample = 0.0
        var greenValueOfSample = 0.0

        for channel in 0 ... 1 { // We are only checking the first two channels
            let extentVector = CIVector(
                x: self.extent.origin.x,
                y: self.extent.origin.y,
                z: self.extent.size.width,
                w: self.extent.size.height
            )

            guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: self, kCIInputExtentKey: extentVector])
            else { XCTFail("It wasn't possible to set the CIFilter for the predominant color channel check")
                return nil
            }
            guard let outputImage = filter.outputImage
            else { XCTFail("It wasn't possible to set the output image for the predominant color channel check")
                return nil
            }

            var outputBitmap = [UInt8](repeating: 0, count: 4)
            let nullSingletonInstance = try XCTUnwrap(kCFNull, "Could not unwrap singleton null instance")
            let outputRenderContext = CIContext(options: [.workingColorSpace: nullSingletonInstance])
            outputRenderContext.render(
                outputImage,
                toBitmap: &outputBitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: nil
            )
            if channel == 0 {
                redValueOfSample = Double(outputBitmap[channel]) / Double(255)
            } else if channel == 1 {
                greenValueOfSample = Double(outputBitmap[channel]) / Double(255)
            }
        }

        let tooSimilar = abs(redValueOfSample - greenValueOfSample) < 0.05 // This isn't a huge difference because these are both very light colors
        if tooSimilar {
            print(
                "It wasn't possible to get a predominant color of the button because the two channel values of red (\(redValueOfSample)) and green (\(greenValueOfSample)) were \(redValueOfSample == greenValueOfSample ? "the same." : "too close in value.")"
            )
            return .neither
        }

        return max(redValueOfSample, greenValueOfSample) == redValueOfSample ? .red : .green
    }
}
