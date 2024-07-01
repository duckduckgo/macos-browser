//
//  OnboardingNavigatingTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class OnboardingNavigatingTests: XCTestCase {

    var onboardingNavigation: OnboardingNavigating!

    @MainActor
    override func setUp() {
        super.setUp()
        onboardingNavigation = WindowControllersManager.shared
    }

    override func tearDown() {
        onboardingNavigation = nil
        super.tearDown()
    }

    @MainActor
    func testOnImportData_DataImportViewShown() {
        // Given
        let mockWindow = MockWindow()
        let mvc = MainWindowController(mainViewController: MainViewController(autofillPopoverPresenter: DefaultAutofillPopoverPresenter()), popUp: false)
        mvc.window = mockWindow
        WindowControllersManager.shared.lastKeyMainWindowController = mvc

        // When
        onboardingNavigation.showImportDataView()

        // Then
        XCTAssertTrue(mockWindow.beginSheetCalled, "A sheet should be begun on the window")
    }

    @MainActor
    func testOnFocusOnAddressBar_AddressBarIsFocussed() {
        // When
        onboardingNavigation.focusOnAddressBar()

        // Then
        guard let mainVC = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController else { return }
        XCTAssertTrue(mainVC.navigationBarViewController.addressBarViewController?.addressBarTextField.stringValue.isEmpty ?? false)
        XCTAssertTrue(mainVC.navigationBarViewController.addressBarViewController?.addressBarTextField.isFirstResponder ?? false)
    }

}
