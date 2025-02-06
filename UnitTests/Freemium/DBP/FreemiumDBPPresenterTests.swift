//
//  FreemiumDBPPresenterTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
import Combine

final class FreemiumDBPPresenterTests: XCTestCase {

    private var mockWindowControllerManager: MockWindowControllerManager!
    private var mockFreemiumDBPStateManager: MockFreemiumDBPUserStateManager!

    @MainActor
    func testWhenCallShowFreemiumDBPThenShowPIRTabIsCalledAndActivatedStateIsSet() async throws {
        // Given
        mockWindowControllerManager = MockWindowControllerManager()
        mockFreemiumDBPStateManager = MockFreemiumDBPUserStateManager()
        let sut = DefaultFreemiumDBPPresenter(freemiumDBPStateManager: mockFreemiumDBPStateManager)
        XCTAssertFalse(mockFreemiumDBPStateManager.didActivate)
        // When
        sut.showFreemiumDBPAndSetActivated(windowControllerManager: mockWindowControllerManager)
        // Then
        XCTAssertEqual(mockWindowControllerManager.showTabContent, Tab.Content.dataBrokerProtection)
        XCTAssertTrue(mockFreemiumDBPStateManager.didActivate)
    }
}

private final class MockWindowControllerManager: WindowControllersManagerProtocol {
    var mainWindowControllers: [DuckDuckGo_Privacy_Browser.MainWindowController] = []

    var lastKeyMainWindowController: DuckDuckGo_Privacy_Browser.MainWindowController?

    var showTabContent: Tab.Content = .none

    var pinnedTabsManager: PinnedTabsManager = PinnedTabsManager()

    var didRegisterWindowController: PassthroughSubject<(MainWindowController), Never> = PassthroughSubject<(MainWindowController), Never>()

    var didUnregisterWindowController: PassthroughSubject<(MainWindowController), Never> = PassthroughSubject<(MainWindowController), Never>()

    func register(_ windowController: MainWindowController) {}

    func unregister(_ windowController: MainWindowController) {}

    func showTab(with content: Tab.TabContent) {
        showTabContent = content
    }

    func show(url: URL?, source: DuckDuckGo_Privacy_Browser.Tab.TabContent.URLSource, newTab: Bool) {}

    func showBookmarksTab() {}

    func openNewWindow(with tabCollectionViewModel: DuckDuckGo_Privacy_Browser.TabCollectionViewModel?, burnerMode: DuckDuckGo_Privacy_Browser.BurnerMode, droppingPoint: NSPoint?, contentSize: NSSize?, showWindow: Bool, popUp: Bool, lazyLoadTabs: Bool, isMiniaturized: Bool, isMaximized: Bool, isFullscreen: Bool) -> DuckDuckGo_Privacy_Browser.MainWindow? {
        nil
    }
}
