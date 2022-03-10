//
//  Preferences.swift
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

import AppKit
import SwiftUI

enum Preferences {
    
    enum Const {
        enum Font {
            static let popUpButton = NSFont.systemFont(ofSize: 22, weight: .semibold)
            static let sideBarItem = SwiftUI.Font.system(size: 13, weight: .medium)
        }
    }
}

enum PreferencesListSectionIdentifier: Hashable, CaseIterable {
    case regularPreferencePanes
    case about
}

struct PreferencesSection: Hashable, Identifiable {
    let id: PreferencesListSectionIdentifier
    let panes: [PreferencePane]
}

struct PreferencePane: PreferenceSection, Hashable, Identifiable {
    let id = UUID()
    let displayName: String
    let preferenceIcon: NSImage
    
    init(displayName: String, preferenceIcon: NSImage) {
        self.displayName = displayName
        self.preferenceIcon = preferenceIcon
    }
    
    init(preferenceSection: PreferenceSection) {
        displayName = preferenceSection.displayName
        preferenceIcon = preferenceSection.preferenceIcon
    }
}

struct PreferencesSections {
    let sections: [PreferencesSection]
    
    init(sections: [PreferencesSection] = [
        .init(
            id: .regularPreferencePanes,
            panes: [
                DefaultBrowserPreferences(),
                AppearancePreferences(),
                PrivacySecurityPreferences.shared,
                LoginsPreferences(),
                DownloadPreferences()
            ]
                .map(PreferencePane.init(preferenceSection:))
        ),
        .init(
            id: .about,
            panes: [.init(displayName: "About", preferenceIcon: NSImage(named: "About")!)]
        )
    ]) {
        self.sections = sections
    }
}
