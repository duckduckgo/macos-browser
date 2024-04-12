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
class PermissionsTests: XCTestCase {
    private var app: XCUIApplication!
    private var notificationCenter: XCUIApplication!
    private var addressBarTextField: XCUIElement!

    override class func setUp() {
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        notificationCenter = XCUIApplication(bundleIdentifier: "com.apple.UserNotificationCenter")
        app.launchEnvironment["UITEST_MODE"] = "1"
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        app.launch()

        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Enforce a single window
        app.typeKey("n", modifierFlags: .command)
    }

    func test_cameraPermissions_withAcceptedTCCChallenge_showCorrectStateInBrowser() throws {
        let url = try XCTUnwrap(URL(string: "https://permission.site/"))
        app.resetAuthorizationStatus(for: .camera)
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURLAfterExistenceTestSucceeds(url)

        let cameraButton = app.webViews.buttons["Camera"]
        cameraButton.clickAfterExistenceTestSucceeds()
        sleep(UITests.Timeouts.sleepTimeForTCCDialogAppearance) // The rare necessary sleep, since we can believe a TCC dialog will appear here
        let allowButtonIndex = try XCTUnwrap(notificationCenter.indexOfSystemModelDialogButtonOnElement(titled: "Allow"))
        let allowButton = notificationCenter.buttons.element(boundBy: allowButtonIndex)
        allowButton.clickAfterExistenceTestSucceeds() // Click system camera permissions dialog
        let permissionsPopoverAllowButton = app.popovers.buttons["PermissionAuthorizationViewController.allowButton"]
        permissionsPopoverAllowButton.clickAfterExistenceTestSucceeds()
        let cameraButtonScreenshot = cameraButton.screenshot().image
        let trimmedCameraButton = cameraButtonScreenshot.trim(to: CGRect(
            x: 10,
            y: 10,
            width: 20,
            height: 20
        )) // A sample of the button that we are going to analyze for its predominant color tone.
        let predominantColor = try XCTUnwrap(trimmedCameraButton.ciImage(with: nil).predominantColor())
        XCTAssertEqual(
            predominantColor,
            .green,
            "The predominant color of a sample area of the Camera button on the webpage should be green at this point in the test."
        )
        let navigationBarViewControllerPermissionButton = app.buttons["NavigationBarViewController.PermissionButton"]
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
}

private extension XCUIElement {
    /// We don't have as much control over what is going to appear on a modal dialogue, and it feels fragile to use Apple's accessibility IDs since I
    /// don't think there is any contract for that, but we can plan some flexibility in title matching for the button names, since the button names
    /// are
    /// in the test description.
    /// - Parameter titled: The title of a button whose index on the element we'd like to know
    /// - Returns: An optional Int representing the button index on the element, if a button with this title was found.
    func indexOfSystemModelDialogButtonOnElement(titled: String) -> Int? {
        for buttonIndex in 0 ... 4 { // It feels unlikely that a system modal dialog will have more than five buttons
            let button = self.buttons.element(boundBy: buttonIndex)
            if button.exists, button.title == titled {
                return buttonIndex
            }
        }
        return nil
    }
}

/// Understand whether a webpage button is greenish or reddish when we expect one or the other
private enum PredominantColor {
    case red
    case green
    case unknown
}

private extension NSImage {
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
    /// Evaluate a sample of a webpage button to see what its predominant color tone is
    /// - Returns: .red, .green, or .unknown.
    func predominantColor() throws -> PredominantColor {
        var redValueOfSample = 0.0
        var greenValueOfSample = 0.0

        for channel in 0 ... 1 {
            let extentVector = CIVector(
                x: self.extent.origin.x,
                y: self.extent.origin.y,
                z: self.extent.size.width,
                w: self.extent.size.height
            )

            guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: self, kCIInputExtentKey: extentVector])
            else { XCTFail("It wasn't possible to set the CIFilter for the predominant color channel check")
                return .unknown
            }
            guard let outputImage = filter.outputImage
            else { XCTFail("It wasn't possible to set the output image for the predominant color channel check")
                return .unknown
            }

            var bitmap = [UInt8](repeating: 0, count: 4)
            let null = try XCTUnwrap(kCFNull, "Could not unwrap singleton null instance")
            let context = CIContext(options: [.workingColorSpace: null])
            context.render(
                outputImage,
                toBitmap: &bitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: nil
            )
            switch channel {
            case 0:
                redValueOfSample = Double(bitmap[channel]) / Double(255)
            case 1:
                greenValueOfSample = Double(bitmap[channel]) / Double(255)
            default:
                break
            }
        }

        if abs(redValueOfSample - greenValueOfSample) < 0.07 { // This isn't a huge difference because these are both very light colors
            return .unknown // No predominant color
        }
        switch max(redValueOfSample, greenValueOfSample) {
        case redValueOfSample:
            return .red
        case greenValueOfSample:
            return .green
        default:
            return .unknown
        }
    }
}
