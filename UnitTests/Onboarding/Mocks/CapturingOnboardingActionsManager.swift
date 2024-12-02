//
//  CapturingOnboardingActionsManager.swift
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

import Foundation
@testable import DuckDuckGo_Privacy_Browser

class CapturingOnboardingActionsManager: OnboardingActionsManaging {

    var configuration: OnboardingConfiguration = OnboardingConfiguration(
        stepDefinitions: StepDefinitions(systemSettings: SystemSettings(rows: [])),
        exclude: [],
        order: "",
        env: "environment",
        locale: "en",
        platform: .init(name: "")
    )

    var goToAddressBarCalled = false
    var goToSettingsCalled = false
    var addToDockCalled = false
    var importDataCalled = false
    var setAsDefaultCalled = false
    var setBookmarkBarCalled = false
    var setSessionRestoreCalled = false
    var setHomeButtonPositionCalled = false
    var onboardingStartedCalled = false
    var reportExceptionCalled = false
    var exceptionParams: [String: String] = [:]
    var completedStep: OnboardingSteps?
    var bookmarkBarVisible: Bool?
    var homeButtonVisible: Bool?
    var sessionRestoreEnabled: Bool?

    func onboardingStarted() {
        onboardingStartedCalled = true
    }

    func goToAddressBar() {
        goToAddressBarCalled = true
    }

    func goToSettings() {
        goToSettingsCalled = true
    }

    func addToDock() {
        addToDockCalled = true
    }

    func importData() async -> Bool {
        importDataCalled = true
        return true
    }

    func setAsDefault() {
        setAsDefaultCalled = true
    }

    func setBookmarkBar(enabled: Bool) {
        setBookmarkBarCalled = true
        bookmarkBarVisible = enabled
    }

    func setSessionRestore(enabled: Bool) {
        setSessionRestoreCalled = true
        sessionRestoreEnabled = enabled
    }

    func setHomeButtonPosition(enabled: Bool) {
        setHomeButtonPositionCalled = true
        homeButtonVisible = enabled
    }

    func stepCompleted(step: OnboardingSteps) {
        completedStep = step
    }

    func reportException(with param: [String: String]) {
        reportExceptionCalled = true
        exceptionParams = param
    }
}
