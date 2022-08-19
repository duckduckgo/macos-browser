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

struct AdaptiveDarkModeManager {
    @UserDefaultsWrapper(key: .adaptiveDarkModeDiscoveryPopUpDisplayed, defaultValue: false)
    private var adaptiveDarkModeDiscoveryPopUpDisplayed: Bool
    private let darkSitesManager = DarkSitesConfigManager()
    
    private var isDarkThemeEnabled: Bool {
        ((AppearancePreferences.shared.currentThemeName == .dark) ||
                (AppearancePreferences.shared.currentThemeName == .systemDefault) && NSApp.effectiveAppearance.name == .darkAqua)
    }
    
#warning("darkSitesManager.isURLInList is being called twice, this should be fixed")
    // shouldDisplayFeatureDiscoveryPopUp and shouldDisplayNavigationBarButton
    func shouldDisplayFeatureDiscoveryPopUp(withDomain domain: String) -> Bool {
        
        guard isDarkThemeEnabled,
              !adaptiveDarkModeDiscoveryPopUpDisplayed,
              let url = URL(string: domain),
              !darkSitesManager.isURLInList(url) else { return false }
        
        return true
    }
    
    mutating func setDiscoveryPopUpAsDisplayed() {
        self.adaptiveDarkModeDiscoveryPopUpDisplayed = true
    }
    
    func shouldDisplayNavigationBarButton(withDomain domain: String) -> Bool {
        
        if isDarkThemeEnabled,
           AppearancePreferences.shared.useAdaptiveDarkMode,
           let url = URL(string: domain),
           !darkSitesManager.isURLInList(url) {
            return true
        }
        
        return false
    }
    
    private func doesWebsiteImplementsColorSchemeDark() -> Bool {
        return true
    }
}
