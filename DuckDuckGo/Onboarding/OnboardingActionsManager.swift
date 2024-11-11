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
import PixelKit
import Common
import os.log

enum OnboardingSteps: String, CaseIterable {
    case welcome
    case getStarted
    case makeDefaultSingle
    case systemSettings
    case duckPlayerSingle
    case customize
}

protocol OnboardingActionsManaging {
    /// Provides the configuration needed to set up the FE onboarding
    var configuration: OnboardingConfiguration { get }

    /// Used for any setup necessary for during the onboarding
    func onboardingStarted()

    /// At the end of the onboarding the user will be taken to the DuckDuckGo search page
    func goToAddressBar()

    /// At the end of the onboarding the user can be taken to the Settings page
    func goToSettings()

    /// At user imput adds the app to the dock
    func addToDock()

    /// At user imput shows the import data flow
    func importData() async -> Bool

    /// At user imput shows the system prompt to change default browser
    func setAsDefault()

    /// At user imput shows the bookmarks bar
    func setBookmarkBar(enabled: Bool)

    /// At user imput set the session restoration on startup
    func setSessionRestore(enabled: Bool)

    /// At user imput set the session restoration on startup
    func setHomeButtonPosition(enabled: Bool)

    /// It is called every time the user ends an onboarding step
    func stepCompleted(step _: OnboardingSteps)

    /// It is called in case of error loading the pages
    func reportException(with param: [String: String])
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
    private let dataImportProvider: DataImportStatusProviding
    private var cancellables = Set<AnyCancellable>()

    @UserDefaultsWrapper(key: .onboardingFinished, defaultValue: false)
    static private(set) var isOnboardingFinished: Bool

    let configuration: OnboardingConfiguration = {
        var systemSettings: SystemSettings
        var order = "v3"
        let platform = OnboardingPlatform(name: "macos")
#if APPSTORE
        systemSettings = SystemSettings(rows: ["import"])
#else
        systemSettings = SystemSettings(rows: ["dock", "import"])
#endif
        let stepDefinitions = StepDefinitions(systemSettings: systemSettings)
        let preferredLocale = Bundle.main.preferredLocalizations.first ?? "en"
        var env: String
#if DEBUG || REVIEW
        env = "development"
#else
        env = "production"
#endif

        return OnboardingConfiguration(stepDefinitions: stepDefinitions, exclude: [], order: order, env: env, locale: preferredLocale, platform: platform)
    }()

    init(navigationDelegate: OnboardingNavigating,
         dockCustomization: DockCustomization,
         defaultBrowserProvider: DefaultBrowserProvider,
         appearancePreferences: AppearancePreferences,
         startupPreferences: StartupPreferences,
         dataImportProvider: DataImportStatusProviding = BookmarksAndPasswordsImportStatusProvider()) {
        self.navigation = navigationDelegate
        self.dockCustomization = dockCustomization
        self.defaultBrowserProvider = defaultBrowserProvider
        self.appearancePreferences = appearancePreferences
        self.startupPreferences = startupPreferences
        self.dataImportProvider = dataImportProvider
    }

    func onboardingStarted() {
        navigation.updatePreventUserInteraction(prevent: true)
    }

    @MainActor
    func goToAddressBar() {
        PixelKit.fire(GeneralPixel.onboardingStepCompleteCustomize, frequency: .legacyDaily)
        onboardingHasFinished()
        let tab = Tab(content: .url(URL.duckDuckGo, source: .ui))
        navigation.replaceTabWith(tab)

        tab.navigationDidEndPublisher
            .first()
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
    func importData() async -> Bool {
        return await withCheckedContinuation { continuation in
            dataImportProvider.showImportWindow(customTitle: UserText.importDataTitleOnboarding, completion: { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: self.dataImportProvider.didImport)
            })
        }
    }

    func setAsDefault() {
        try? defaultBrowserProvider.presentDefaultBrowserPrompt()
    }

    func setBookmarkBar(enabled: Bool) {
        appearancePreferences.showBookmarksBar = enabled
    }

    func setSessionRestore(enabled: Bool) {
        startupPreferences.restorePreviousSession = enabled
    }

    func setHomeButtonPosition(enabled: Bool) {
        onMainThreadIfNeeded {
            self.startupPreferences.homeButtonPosition = enabled ? .left : .hidden
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
        switch step {
        case .welcome:
            PixelKit.fire(GeneralPixel.onboardingStepCompleteWelcome, frequency: .legacyDaily)
        case .getStarted:
            PixelKit.fire(GeneralPixel.onboardingStepCompleteGetStarted, frequency: .legacyDaily)
        case .makeDefaultSingle:
            PixelKit.fire(GeneralPixel.onboardingStepCompletePrivateByDefault, frequency: .legacyDaily)
        case .systemSettings:
            PixelKit.fire(GeneralPixel.onboardingStepCompleteSystemSettings, frequency: .legacyDaily)
        case .duckPlayerSingle:
            PixelKit.fire(GeneralPixel.onboardingStepCompleteCleanerBrowsing, frequency: .legacyDaily)
        case .customize:
            PixelKit.fire(GeneralPixel.onboardingStepCompleteCustomize, frequency: .legacyDaily)
        }
    }

    func reportException(with param: [String: String]) {
        let message = param["message"] ?? ""
        let id = param["id"] ?? ""
        PixelKit.fire(GeneralPixel.onboardingExceptionReported(message: message, id: id), frequency: .standard)
        Logger.general.error("Onboarding error: \("\(id): \(message)", privacy: .public)")
    }

    private func onboardingHasFinished() {
        Self.isOnboardingFinished = true
        navigation.updatePreventUserInteraction(prevent: false)
    }

}
