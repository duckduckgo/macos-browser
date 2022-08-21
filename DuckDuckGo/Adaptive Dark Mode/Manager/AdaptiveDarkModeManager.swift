//
//  AdaptiveDarkModeManager.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class AdaptiveDarkModeManager {
    private let darkSitesConfigManager: DarkSitesConfigManager
    private let appearancePreferences: AppearancePreferences
    private let settingsStore: DarkModeSettingsStore
    private var tabCancellable: AnyCancellable?
    private var preferencesCancellable: AnyCancellable?

    @Published var adaptiveDarkModeAvailable: Bool = false
    @Published var shouldDisplayDiscoveryPopUp: Bool = false
  
    @Published var currentTabDarkModeEnabled: Bool = false {
        didSet {
            tab?.isDarkModeEnabled = currentTabDarkModeEnabled
        }
    }
 
    @UserDefaultsWrapper(key: .adaptiveDarkModeDiscoveryPopUpDisplayed, defaultValue: false)
    private var adaptiveDarkModeDiscoveryPopUpDisplayed: Bool

    weak var tab: Tab? {
        didSet {
            if let tab = tab {
                subscribeToTabContentChange(tab)
            } else {
                adaptiveDarkModeAvailable = false
                currentTabDarkModeEnabled = false
            }
        }
    }
    
    private var currentDomain: String {
        tab?.url?.host?.dropWWW() ?? ""
    }
    
    private var isAdaptiveDarkModeOn: Bool {
        appearancePreferences.useAdaptiveDarkMode
    }
    
    private var isDarkThemeOn: Bool {
        ((appearancePreferences.currentThemeName == .dark) ||
         (appearancePreferences.currentThemeName == .systemDefault) && NSApp.effectiveAppearance.name == .darkAqua)
    }
    
#warning("UserScript should return the real flag here")
    private var isPreferColorSchemeDarkSupported: Bool {
        return false
    }
    
    internal init(darkSitesConfigManager: DarkSitesConfigManager = .shared,
                  appearancePreferences: AppearancePreferences = .shared,
                  settingsStore: DarkModeSettingsStore = .shared,
                  tab: Tab? = nil) {
        self.darkSitesConfigManager = darkSitesConfigManager
        self.appearancePreferences = appearancePreferences
        self.settingsStore = settingsStore
        self.tab = tab
        
        self.subscribeToPreferencesChange()
    }
    
    func enableAdaptiveDarkMode(_ enable: Bool) {
        adaptiveDarkModeDiscoveryPopUpDisplayed = true
        appearancePreferences.useAdaptiveDarkMode = enable
        
        if let tab = tab {
            setupDarkModeWithTab(tab)
        }
    }
    
    private func subscribeToPreferencesChange() {
        preferencesCancellable = appearancePreferences.$useAdaptiveDarkMode
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                if value {
                    self?.adaptiveDarkModeDiscoveryPopUpDisplayed = true
                }
            })
    }
    
    private func subscribeToTabContentChange(_ tab: Tab) {
        tabCancellable = tab.$content
            .receive(on: DispatchQueue.main)
            .throttle(for: .seconds(0.7), scheduler: DispatchQueue.main, latest: true)
            .removeDuplicates()
            .sink(receiveValue: { [weak self] _ in
                self?.setupDarkModeWithTab(tab)
            })
   }
    
    private func setupDarkModeWithTab(_ tab: Tab) {
        if tab.url != nil,
           (isAdaptiveDarkModeOn || !adaptiveDarkModeDiscoveryPopUpDisplayed),
           isDarkThemeOn,
           !isPreferColorSchemeDarkSupported,
           !isTabURLonDarkSitesConfig(tab) {
            adaptiveDarkModeAvailable = true
        } else {
            adaptiveDarkModeAvailable = false
            currentTabDarkModeEnabled = false
            return
        }
        
        if !adaptiveDarkModeDiscoveryPopUpDisplayed {
            shouldDisplayDiscoveryPopUp = true
        } else {
            currentTabDarkModeEnabled = !isTabDomainOnExceptionList(tab)
        }
    }
    
    func removeCurrentTabFromExceptionList() {
        settingsStore.removeDomainFromExceptionList(domain: currentDomain)
        currentTabDarkModeEnabled = true
    }
    
    func addCurrentTabToExceptionList() {
        settingsStore.addDomainToExceptionList(domain: currentDomain)
        currentTabDarkModeEnabled = false
    }
    
    private func isTabDomainOnExceptionList(_ tab: Tab) -> Bool {
        return settingsStore.isDomainOnExceptionList(domain: currentDomain)
    }
    
    private func isTabURLonDarkSitesConfig(_ tab: Tab) -> Bool {
        guard let url = tab.url else { return false }
        return darkSitesConfigManager.isURLInList(url)
    }
}
