//
//  OnboardingManagerTests.swift
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
import SwiftUI

class OnboardingManagerTests: XCTestCase {

    var manager: OnboardingActionsManaging!
    var navigationDelegate: CapturingOnboardingNavigationDelegate!
    var dockCustomization: CapturingDockCustomizer!
    var dataImportView: DataImportView!
    var defaultBrowserProvider: CapturingDefaultBrowserProvider!
    var apperancePreferences: AppearancePreferences!
    var startupPreferences: StartupPreferences!
    var appearancePersistor: MockAppearancePreferencesPersistor!
    var startupPersistor: StartupPreferencesUserDefaultsPersistor!

    @MainActor override func setUp() {
        super.setUp()
        dataImportView = DataImportView()
        navigationDelegate = CapturingOnboardingNavigationDelegate()
        dockCustomization = CapturingDockCustomizer()
        dataImportView = DataImportView()
        defaultBrowserProvider = CapturingDefaultBrowserProvider()
        appearancePersistor = MockAppearancePreferencesPersistor()
        apperancePreferences = AppearancePreferences(persistor: appearancePersistor)
        startupPersistor = StartupPreferencesUserDefaultsPersistor(appearancePrefs: apperancePreferences)
        startupPreferences = StartupPreferences(persistor: startupPersistor)
        manager = OnboardingActionsManager(navigationDelegate: navigationDelegate, dockCustomization: dockCustomization, dataImportView: dataImportView, defaultBrowserProvider: defaultBrowserProvider, appearancePreferences: apperancePreferences, startupPreferences: startupPreferences)
    }

    override func tearDown() {
        manager = nil
        navigationDelegate = nil
        dockCustomization = nil
        dataImportView = nil
        defaultBrowserProvider = nil
        apperancePreferences = nil
        startupPreferences = nil
        super.tearDown()
    }

    func testReturnsExpectedOnboardingConfig() {
        // Given
        var systemSettings: SystemSettings
#if APPSTORE
        systemSettings = SystemSettings(rows: ["import", "default-browser"])
#else
        systemSettings = SystemSettings(rows: ["dock", "import", "default-browser"])
#endif
        let stepDefinitions = StepDefinitions(systemSettings: systemSettings)
        let expectedConfig = OnboardingConfiguration(stepDefinitions: stepDefinitions, env: "development")

        // Then
        XCTAssertEqual(manager.configuration, expectedConfig)
    }

    func testGoToAddressBar_NavigatesToSearch() {
        // When
        manager.goToAddressBar()

        // Then
        XCTAssertTrue(navigationDelegate.goToSearchFromOnboardingCalled)
    }

    func testGoToAddressBar_NavigatesToSettings() {
        // When
        manager.goToSettings()

        // Then
        XCTAssertTrue(navigationDelegate.goToSettingsFromOnboardingCalled)
    }

    @MainActor
    func testOnImportData_DataImportViewShown2() {
        // Given
        let mockWindow = MockOnboardingWindow()
        let mvc = MainWindowController(mainViewController: MainViewController(autofillPopoverPresenter: DefaultAutofillPopoverPresenter()), popUp: false)
        mvc.window = mockWindow
        WindowControllersManager.shared.lastKeyMainWindowController = mvc

        // When
        manager.importData()

        // Then
        XCTAssertTrue(mockWindow.beginSheetCalled, "A sheet should be begun on the window")
    }

    func testOnAddToDock_IsAddedToDock() {
        // When
        manager.addToDock()

        // Then
        XCTAssertTrue(dockCustomization.isAddedToDock)
    }

    func testOnSetAsDefault_DefaultPromptShown() {
        // When
        manager.setAsDefault()

        // Then
        XCTAssertTrue(defaultBrowserProvider.presentDefaultBrowserPromptCalled)
    }

    func testOnSetBookmarksBar_BookmarksBarIsShown() {
        // When
        manager.setBookmarkBar()

        // Then
        XCTAssertTrue(appearancePersistor.showBookmarksBar)
    }

    func testOnSetSessionRestore_sessionRestorationSet() {
        // When
        manager.setSessionRestore()

        // Then
        XCTAssertTrue(startupPersistor.restorePreviousSession)
    }

    func testOnShowHomeButtonLeft_homeButtonShown() {
        // When
        manager.setShowHomeButtonLeft()

        // Then
        XCTAssertEqual(appearancePersistor.homeButtonPosition, .left)
    }

}
