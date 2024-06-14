//
//  OnboardingActionsManager.swift
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

enum OnboardingSteps: String {
    case summary
    case welcome
    case getStarted
    case privateByDefault
    case cleanerBrowsing
    case systemSettings
    case customize
}

protocol OnboardingActionsManaging {
    var configuration: OnboardingConfiguration { get }
    func goToAddressBar()
    func goToSettings()
    func addToDock()
    func importData()
    func setAsDefault()
    func setBookmarkBar()
    func setSessionRestore()
    func setShowHomeButtonLeft()
    func stepCompleted(step _: OnboardingSteps)
}

protocol OnboardingNavigationDelegate: AnyObject {
    func goToSearchFromOnboarding()
    func goToSettingsFromOnboarding()
}

struct OnboardingActionsManager: OnboardingActionsManaging {

    weak var navigationDelegate: OnboardingNavigationDelegate?
    let dockCustomization: DockCustomization
    let dataImportView: DataImportView
    let defaultBrowserProvider: DefaultBrowserProvider
    let appearancePreferences: AppearancePreferences
    let startupPreferences: StartupPreferences

    let configuration: OnboardingConfiguration = {
        var systemSettings: SystemSettings
#if APPSTORE
        systemSettings = SystemSettings(rows: ["import", "default-browser"])
#else
        systemSettings = SystemSettings(rows: ["dock", "import", "default-browser"])
#endif
        let stepDefinitions = StepDefinitions(systemSettings: systemSettings)
        return OnboardingConfiguration(stepDefinitions: stepDefinitions, env: "development")
    }()

    func goToAddressBar() {
        navigationDelegate?.goToSearchFromOnboarding()
    }

    func goToSettings() {
        navigationDelegate?.goToSettingsFromOnboarding()
    }

    func addToDock() {
        dockCustomization.addToDock()
    }

    @MainActor
    func importData() {
        dataImportView.show(in: nil, completion: nil)
    }

    func setAsDefault() {
        try? defaultBrowserProvider.presentDefaultBrowserPrompt()
    }

    func setBookmarkBar() {
        appearancePreferences.showBookmarksBar = true
    }

    func setSessionRestore() {
        startupPreferences.restorePreviousSession = true
    }

    func setShowHomeButtonLeft() {
        startupPreferences.homeButtonPosition = .left
        startupPreferences.updateHomeButton()
    }

    func stepCompleted(step _: OnboardingSteps) {
        // Will send pixels
    }

}
