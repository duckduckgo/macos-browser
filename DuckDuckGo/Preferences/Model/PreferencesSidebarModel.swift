//
//  PreferencesSidebarModel.swift
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

import SwiftUI

final class PreferencesSidebarModel: ObservableObject {

    let sections: [PreferencesSection]
    let tabSwitcherTabs: [Tab.TabContent]

    @Published var selectedTabIndex: Int = 0

    @Published private(set) var selectedPane: PreferencePaneIdentifier = .defaultBrowser

    init(
        sections: [PreferencesSection] = PreferencesSection.defaultSections,
        tabSwitcherTabs: [Tab.TabContent] = Tab.TabContent.displayableTabTypes
    ) {
        self.sections = sections
        self.tabSwitcherTabs = tabSwitcherTabs
        resetTabSelectionIfNeeded()
        if let firstPane = sections.first?.panes.first {
            selectedPane = firstPane
        }
    }

    func selectPane(_ identifier: PreferencePaneIdentifier) {
        if sections.flatMap(\.panes).contains(identifier), identifier != selectedPane {
            selectedPane = identifier
        }
    }

    func resetTabSelectionIfNeeded() {
        if let preferencesTabIndex = tabSwitcherTabs.firstIndex(of: .anyPreferencePane) {
            if preferencesTabIndex != selectedTabIndex {
                selectedTabIndex = preferencesTabIndex
            }
        }
    }
}
