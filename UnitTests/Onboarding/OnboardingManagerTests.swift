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
    var navigationDelegate: CapturingOnboardingNavigation!
    var dockCustomization: CapturingDockCustomizer!
    var defaultBrowserProvider: CapturingDefaultBrowserProvider!
    var apperancePreferences: AppearancePreferences!
    var startupPreferences: StartupPreferences!
    var appearancePersistor: MockAppearancePreferencesPersistor!
    var startupPersistor: StartupPreferencesUserDefaultsPersistor!

    @MainActor override func setUp() {
        super.setUp()
        navigationDelegate = CapturingOnboardingNavigation()
        dockCustomization = CapturingDockCustomizer()
        defaultBrowserProvider = CapturingDefaultBrowserProvider()
        appearancePersistor = MockAppearancePreferencesPersistor()
        apperancePreferences = AppearancePreferences(persistor: appearancePersistor)
        startupPersistor = StartupPreferencesUserDefaultsPersistor(appearancePrefs: apperancePreferences)
        startupPreferences = StartupPreferences(persistor: startupPersistor)
        manager = OnboardingActionsManager(navigationDelegate: navigationDelegate, dockCustomization: dockCustomization, defaultBrowserProvider: defaultBrowserProvider, appearancePreferences: apperancePreferences, startupPreferences: startupPreferences)
    }

    override func tearDown() {
        manager = nil
        navigationDelegate = nil
        dockCustomization = nil
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

    func testOnOnboardingStarted_UserInteractionIsPrevented() {
        // When
        manager.onboardingStarted()

        // Then
        XCTAssertTrue(navigationDelegate.updatePreventUserInteractionCalled)
        XCTAssertTrue(navigationDelegate.preventUserInteraction ?? false)
    }

    func testGoToAddressBar_NavigatesToSearch() {
        // Given
        OnboardingActionsManager.isOnboardingFinished = false

        // When
        manager.goToAddressBar()

        // Then
        XCTAssertTrue(navigationDelegate.replaceTabCalled)
        XCTAssertEqual(navigationDelegate.tab?.url, URL.duckDuckGo)
        XCTAssertTrue(navigationDelegate.updatePreventUserInteractionCalled)
        XCTAssertFalse(navigationDelegate.preventUserInteraction ?? true)
        XCTAssertTrue(OnboardingActionsManager.isOnboardingFinished)
    }

    func testGoToAddressBar_NavigatesToSearch_AndFocusOnBar() {
        // Given
        OnboardingActionsManager.isOnboardingFinished = false

        // When
        manager.goToAddressBar()

        // Then
        XCTAssertTrue(navigationDelegate.replaceTabCalled)
        XCTAssertEqual(navigationDelegate.tab?.url, URL.duckDuckGo)
        XCTAssertTrue(navigationDelegate.updatePreventUserInteractionCalled)
        XCTAssertFalse(navigationDelegate.preventUserInteraction ?? true)
        XCTAssertTrue(OnboardingActionsManager.isOnboardingFinished)

        // When
        navigationDelegate.fireNavigationDidEnd()

        // Then
        XCTAssertTrue(navigationDelegate.focusOnAddressBarCalled)
    }

    func testGoToAddressBar_NavigatesToSettings() {
        // When
        manager.goToSettings()

        // Then
        XCTAssertTrue(navigationDelegate.replaceTabCalled)
        XCTAssertEqual(navigationDelegate.tab?.url, URL.settings)
    }

    @MainActor
    func testOnImportData_DataImportViewShown() {
        // When
        manager.importData()

        // Then
        XCTAssertTrue(navigationDelegate.showImportDataViewCalled)
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

    func testOnSetBookmarksBar_andBarNotShown_ThenBarIsShown() {
        // When
        manager.setBookmarkBar()

        // Then
        XCTAssertTrue(appearancePersistor.showBookmarksBar)
    }

    func testOnSetBookmarksBar_andBarIsShown_ThenBarIsShown() {
        // Given
        apperancePreferences.showBookmarksBar = true

        // When
        manager.setBookmarkBar()

        // Then
        XCTAssertFalse(appearancePersistor.showBookmarksBar)
    }

    func testOnSetSessionRestore_andSessionRestoreOff_sessionRestorationSetOn() {
        // When
        manager.setSessionRestore()

        // Then
        XCTAssertTrue(startupPersistor.restorePreviousSession)
    }

    func testOnSetSessionRestore_andSessionRestoreOn_sessionRestorationSetOff() {
        // Given
        startupPreferences.restorePreviousSession = true

        // When
        manager.setSessionRestore()

        // Then
        XCTAssertFalse(startupPersistor.restorePreviousSession)
    }

    func testsetHomeButtonPosition_ifHidden_homeButtonShown() {
        // When
        manager.setHomeButtonPosition()

        // Then
        XCTAssertEqual(self.appearancePersistor.homeButtonPosition, .left)
    }

    func testsetHomeButtonPosition_ifShown_homeButtonHidden() {
        // Given
        startupPreferences.homeButtonPosition = .left

        // When
        manager.setHomeButtonPosition()

        // Then
        XCTAssertEqual(self.appearancePersistor.homeButtonPosition, .hidden)
    }

}
