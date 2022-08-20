//
//  AdaptiveDarkModeManagerNew.swift
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

final class AdaptiveDarkModeManagerNew {
    private let darkSitesConfigManager: DarkSitesConfigManager
    private let appearancePreferences: AppearancePreferences
    private let settingsStore: DarkModeSettingsStore
    @Published var adaptiveDarkModeAvailable: Bool = false
    @Published var currentTabDarkModeEnabled: Bool = false
    private var tabCancellable: AnyCancellable?
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
           isAdaptiveDarkModeOn,
           isDarkThemeOn,
           !isPreferColorSchemeDarkSupported,
           !isTabURLonDarkSitesConfig(tab) {
            adaptiveDarkModeAvailable = true
        } else {
            adaptiveDarkModeAvailable = false
        }
        
        self.currentTabDarkModeEnabled = !isTabURLonDarkSitesConfig(tab)
    }
    
    private func isTabDomainOnExceptionList(_ tab: Tab) -> Bool {
        guard let domain = tab.url?.host else { return false }
        print("Checking if \(domain) is on exception list")
        return settingsStore.isDomainOnExceptionList(domain: domain)
    }
    
    private func isTabURLonDarkSitesConfig(_ tab: Tab) -> Bool {
        guard let url = tab.url else { return false }
        print("Checking if \(url) is on dark sites config")
        return darkSitesConfigManager.isURLInList(url)
    }
}
