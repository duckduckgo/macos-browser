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

    /// Used for any setup necessary for during th eonboarding
    func onboardingStarted()

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
    func setHomeButtonPosition()

    /// It is called every time the user ends an onboarding step
    func stepCompleted(step _: OnboardingSteps)
}

protocol OnboardingNavigating: AnyObject {
    func replaceTabWith(_ tab: Tab)
    func focusOnAddressBar()
    func showImportDataView()
    func updatePreventUserInteraction(prevent: Bool)
}

final class OnboardingActionsManager: OnboardingActionsManaging {

    private let navigation: OnboardingNavigating
    private let dockCustomization: DockCustomization
    private let defaultBrowserProvider: DefaultBrowserProvider
    private let appearancePreferences: AppearancePreferences
    private let startupPreferences: StartupPreferences
    private var cancellables = Set<AnyCancellable>()

    @UserDefaultsWrapper(key: .onboardingFinished, defaultValue: false)
    static var isOnboardingFinished: Bool

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
    }

    func onboardingStarted() {
        navigation.updatePreventUserInteraction(prevent: true)
    }

    @MainActor
    func goToAddressBar() {
        onboardingHasFinished()
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
        onboardingHasFinished()
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
        appearancePreferences.showBookmarksBar = !appearancePreferences.showBookmarksBar
    }

    func setSessionRestore() {
        startupPreferences.restorePreviousSession = !startupPreferences.restorePreviousSession
    }

    func setHomeButtonPosition() {
        onMainThreadIfNeeded {
            let currentPosition =  self.startupPreferences.homeButtonPosition
            self.startupPreferences.homeButtonPosition = (currentPosition == .hidden) ? .left : .hidden
            self.startupPreferences.updateHomeButton()
        }
    }

    private func onMainThreadIfNeeded(_ function: @escaping () -> Void) {
        if Thread.isMainThread {
            function()
        } else {
            DispatchQueue.main.sync(execute: function)
        }
    }

    func stepCompleted(step: OnboardingSteps) {
        print(step)
    }

    private func onboardingHasFinished() {
        Self.isOnboardingFinished = true
        navigation.updatePreventUserInteraction(prevent: false)
    }

}
