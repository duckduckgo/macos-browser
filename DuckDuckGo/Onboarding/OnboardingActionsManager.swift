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
import Combine

enum OnboardingSteps: String, CaseIterable {
    case summary
    case welcome
    case getStarted
    case privateByDefault
    case cleanerBrowsing
    case systemSettings
    case customize
}

protocol OnboardingActionsManaging {
    /// Provides the configuration needed to set up the FE onboarding
    var configuration: OnboardingConfiguration { get }

    /// At the end of the onboarding the user will be taken to the DuckDuckGo search page
    func goToAddressBar()

    /// At the end of the onboarding the user can be taken to the Settings page
    func goToSettings()

    /// At user imput adds the app to the dock
    func addToDock()

    /// At user imput shows the import data flow
    func importData()

    /// At user imput shows the system prompt to change default browser
    func setAsDefault()

    /// At user imput shows the bookmarks bar
    func setBookmarkBar()

    /// At user imput set the session restoration on startup
    func setSessionRestore()

    /// At user imput set the session restoration on startup
    func setShowHomeButtonLeft()

    /// It is called every time the user ends an onboarding step
    func stepCompleted(step _: OnboardingSteps)
}

protocol OnboardingNavigating: AnyObject {
    func replaceTabWith(_ tab: Tab)
    func focusOnAddressBar()
    func showImportDataView()
}

final class OnboardingActionsManager: OnboardingActionsManaging {

    let navigation: OnboardingNavigating
    let dockCustomization: DockCustomization
    let defaultBrowserProvider: DefaultBrowserProvider
    let appearancePreferences: AppearancePreferences
    let startupPreferences: StartupPreferences
    let windowsControlManager: WindowControllersManager
    var cancellables = Set<AnyCancellable>()

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

    init(navigationDelegate: OnboardingNavigating, dockCustomization: DockCustomization, defaultBrowserProvider: DefaultBrowserProvider, appearancePreferences: AppearancePreferences, startupPreferences: StartupPreferences) {
        self.navigation = navigationDelegate
        self.dockCustomization = dockCustomization
        self.defaultBrowserProvider = defaultBrowserProvider
        self.appearancePreferences = appearancePreferences
        self.startupPreferences = startupPreferences
        self.windowsControlManager = WindowControllersManager.shared
    }

    @MainActor
    func goToAddressBar() {
        let tab = Tab(content: .url(URL.duckDuckGo, source: .ui))
        navigation.replaceTabWith(tab)

        tab.navigationDidEndPublisher
            .sink { [weak self] _ in
                self?.navigation.focusOnAddressBar()
            }
            .store(in: &cancellables)
    }

    @MainActor
    func goToSettings() {
        let tab = Tab(content: .settings(pane: nil))
        navigation.replaceTabWith(tab)
    }

    func addToDock() {
        dockCustomization.addToDock()
    }

    @MainActor
    func importData() {
        navigation.showImportDataView()
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
        DispatchQueue.main.async { [weak self] in
            self?.startupPreferences.homeButtonPosition = .left
            self?.startupPreferences.updateHomeButton()
        }
    }

    func stepCompleted(step: OnboardingSteps) {
        print(step)
    }

}
