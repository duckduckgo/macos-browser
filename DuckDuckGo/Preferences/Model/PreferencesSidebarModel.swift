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

import BrowserServicesKit
import Combine
import DDGSync
import SwiftUI

#if SUBSCRIPTION
import Subscription
#endif

final class PreferencesSidebarModel: ObservableObject {

    let tabSwitcherTabs: [Tab.TabContent]

    @Published private(set) var sections: [PreferencesSection] = []
    @Published var selectedTabIndex: Int = 0
    @Published private(set) var selectedPane: PreferencePaneIdentifier = .defaultBrowser

    var selectedTabContent: AnyPublisher<Tab.TabContent, Never> {
        $selectedTabIndex.map { [tabSwitcherTabs] in tabSwitcherTabs[$0] }.eraseToAnyPublisher()
    }

    // MARK: - Initializers

    init(
        loadSections: @escaping () -> [PreferencesSection],
        tabSwitcherTabs: [Tab.TabContent],
        privacyConfigurationManager: PrivacyConfigurationManaging,
        syncService: DDGSyncing
    ) {
        self.loadSections = loadSections
        self.tabSwitcherTabs = tabSwitcherTabs

        resetTabSelectionIfNeeded()
        refreshSections()

        let duckPlayerFeatureFlagDidChange = privacyConfigurationManager.updatesPublisher
            .map { [weak privacyConfigurationManager] in
                privacyConfigurationManager?.privacyConfig.isEnabled(featureKey: .duckPlayer) == true
            }
            .removeDuplicates()
            .asVoid()

        let syncFeatureFlagsDidChange = syncService.featureFlagsPublisher.map { $0.contains(.userInterface) }
            .removeDuplicates()
            .asVoid()

        Publishers.Merge(duckPlayerFeatureFlagDidChange, syncFeatureFlagsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshSections()
            }
            .store(in: &cancellables)

        setupVPNPaneVisibility()
    }

    @MainActor
    convenience init(
        tabSwitcherTabs: [Tab.TabContent] = Tab.TabContent.displayableTabTypes,
        privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
        syncService: DDGSyncing,
        includeDuckPlayer: Bool,
        userDefaults: UserDefaults = .netP
    ) {
        let loadSections = {
            let includingVPN = DefaultNetworkProtectionVisibility().isInstalled

            return PreferencesSection.defaultSections(
                includingDuckPlayer: includeDuckPlayer,
                includingSync: syncService.featureFlags.contains(.userInterface),
                includingVPN: includingVPN
            )
        }

        self.init(loadSections: loadSections,
                  tabSwitcherTabs: tabSwitcherTabs,
                  privacyConfigurationManager: privacyConfigurationManager,
                  syncService: syncService)
    }

    // MARK: - Setup

    private func setupVPNPaneVisibility() {
        DefaultNetworkProtectionVisibility().onboardStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }

                self.refreshSections()
            }
            .store(in: &cancellables)
    }

    // MARK: - Refreshing logic

    func refreshSections() {
        sections = loadSections()
        if !sections.flatMap(\.panes).contains(selectedPane), let firstPane = sections.first?.panes.first {
            selectedPane = firstPane
        }
    }

    @MainActor
    func selectPane(_ identifier: PreferencePaneIdentifier) {
        // Open a new tab in case of special panes
        if identifier.rawValue.hasPrefix(URL.NavigationalScheme.https.rawValue),
            let url = URL(string: identifier.rawValue) {
            WindowControllersManager.shared.show(url: url,
                                                 source: .ui,
                                                 newTab: true)
        }

        if sections.flatMap(\.panes).contains(identifier), identifier != selectedPane {
            selectedPane = identifier
        }
    }

    func resetTabSelectionIfNeeded() {
        if let preferencesTabIndex = tabSwitcherTabs.firstIndex(of: .anySettingsPane) {
            if preferencesTabIndex != selectedTabIndex {
                selectedTabIndex = preferencesTabIndex
            }
        }
    }

    private let loadSections: () -> [PreferencesSection]
    private var cancellables = Set<AnyCancellable>()
}
