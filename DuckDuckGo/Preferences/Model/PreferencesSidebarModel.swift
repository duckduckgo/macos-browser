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
import BrowserServicesKit
import Combine

final class PreferencesSidebarModel: ObservableObject {

    let tabSwitcherTabs: [Tab.TabContent]

    @Published private(set) var sections: [PreferencesSection] = []
    @Published var selectedTabIndex: Int = 0
    @Published private(set) var selectedPane: PreferencePaneIdentifier = .general

    init(
        loadSections: @autoclosure @escaping () -> [PreferencesSection] = PreferencesSection.defaultSections,
        tabSwitcherTabs: [Tab.TabContent] = Tab.TabContent.displayableTabTypes,
        privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager
    ) {
        self.loadSections = loadSections
        self.tabSwitcherTabs = tabSwitcherTabs
        resetTabSelectionIfNeeded()
        refreshSections()

        privacyConfigCancellable = privacyConfigurationManager.updatesPublisher
            .map { [weak privacyConfigurationManager] in
                privacyConfigurationManager?.privacyConfig.isEnabled(featureKey: .duckPlayer) == true
            }
            .removeDuplicates()
            .asVoid()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshSections()
            }
    }

    func refreshSections() {
        sections = loadSections()
        if !sections.flatMap(\.panes).contains(selectedPane), let firstPane = sections.first?.panes.first {
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

    private let loadSections: () -> [PreferencesSection]
    private var privacyConfigCancellable: AnyCancellable?
}
