//
//  PreferencesSidebarModelTests.swift
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

import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class PreferencesSidebarModelTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables.removeAll()
    }

    private func PreferencesSidebarModel(loadSections: [PreferencesSection]? = nil, tabSwitcherTabs: [Tab.TabContent] = Tab.TabContent.displayableTabTypes) -> DuckDuckGo_Privacy_Browser.PreferencesSidebarModel {
        return DuckDuckGo_Privacy_Browser.PreferencesSidebarModel(loadSections: { loadSections ?? PreferencesSection.defaultSections(includingPrivatePlayer: false) }, tabSwitcherTabs: tabSwitcherTabs, privacyConfigurationManager: MockPrivacyConfigurationManager())
    }

    func testWhenInitializedThenFirstPaneInFirstSectionIsSelected() throws {
        let sections: [PreferencesSection] = [.init(id: .regularPreferencePanes, panes: [.appearance, .downloads, .autofill])]
        let model = PreferencesSidebarModel(loadSections: sections)

        XCTAssertEqual(model.selectedPane, .appearance)
    }

    func testWhenResetTabSelectionIfNeededCalledThenPreferencesTabIsSelected() throws {
        let tabs: [Tab.TabContent] = [.anyPreferencePane, .bookmarks]
        let model = PreferencesSidebarModel(tabSwitcherTabs: tabs)
        model.selectedTabIndex = 1

        model.resetTabSelectionIfNeeded()

        XCTAssertEqual(model.selectedTabIndex, 0)
    }

    func testWhenSelectPaneIsCalledWithTheSamePaneThenEventIsNotPublished() throws {
        let sections: [PreferencesSection] = [.init(id: .regularPreferencePanes, panes: [.appearance])]
        let model = PreferencesSidebarModel(loadSections: sections)

        var selectedPaneUpdates = [PreferencePaneIdentifier]()
        model.$selectedPane.dropFirst()
            .sink { selectedPaneUpdates.append($0) }
            .store(in: &cancellables)

        model.selectPane(.appearance)
        model.selectPane(.appearance)
        XCTAssertEqual(model.selectedPane, .appearance)
        XCTAssertTrue(selectedPaneUpdates.isEmpty)
    }

    func testWhenSelectPaneIsCalledWithNonexistentPaneThenItHasNoEffect() throws {
        let sections: [PreferencesSection] = [.init(id: .regularPreferencePanes, panes: [.appearance, .downloads])]
        let model = PreferencesSidebarModel(loadSections: sections)

        model.selectPane(.general)
        XCTAssertEqual(model.selectedPane, .appearance)
    }

    func testWhenSelectedTabIndexIsChangedThenSelectedPaneIsNotAffected() throws {
        let sections: [PreferencesSection] = [.init(id: .regularPreferencePanes, panes: [.general, .appearance, .downloads, .autofill])]
        let tabs: [Tab.TabContent] = [.anyPreferencePane, .bookmarks]
        let model = PreferencesSidebarModel(loadSections: sections, tabSwitcherTabs: tabs)

        var selectedPaneUpdates = [PreferencePaneIdentifier]()
        model.$selectedPane.dropFirst()
            .sink { selectedPaneUpdates.append($0) }
            .store(in: &cancellables)

        model.selectPane(.appearance)

        model.selectedTabIndex = 1
        model.selectedTabIndex = 0
        model.selectedTabIndex = 1
        model.selectedTabIndex = 0

        XCTAssertEqual(selectedPaneUpdates, [.appearance])
    }
}
