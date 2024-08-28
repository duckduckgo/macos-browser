//
//  FreemiumPIRPresenterTests.swift
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

final class FreemiumPIRPresenterTests: XCTestCase {

    private var mockWindowControllerManager: MockWindowControllerManager!
    private var sut = DefaultFreemiumPIRPresenter()

    @MainActor
    func testWhenCallShowFreemiumPIRAndDidOnboardThenShowPIRTabIsCalled() async throws {
        // Given
        mockWindowControllerManager = MockWindowControllerManager()
        // When
        sut.showFreemiumPIR(didOnboard: true, windowControllerManager: mockWindowControllerManager)
        // Then
        XCTAssertEqual(mockWindowControllerManager.showTabContent, Tab.Content.dataBrokerProtection)
    }

    @MainActor
    func testWhenCallShowFreemiumPIRAndDidNotOnboardThenShowPIRTabIsNotCalled() async throws {
        // Given
        mockWindowControllerManager = MockWindowControllerManager()
        // When
        sut.showFreemiumPIR(didOnboard: false, windowControllerManager: mockWindowControllerManager)
        // Then
        XCTAssertEqual(mockWindowControllerManager.showTabContent, Tab.Content.dataBrokerProtection)
    }
}

private final class MockWindowControllerManager: WindowControllersManagerProtocol {

    var showTabContent: Tab.Content = .none

    var pinnedTabsManager: PinnedTabsManager = PinnedTabsManager()

    var didRegisterWindowController: PassthroughSubject<(MainWindowController), Never> = PassthroughSubject<(MainWindowController), Never>()

    var didUnregisterWindowController: PassthroughSubject<(MainWindowController), Never> = PassthroughSubject<(MainWindowController), Never>()

    func register(_ windowController: MainWindowController) {}

    func unregister(_ windowController: MainWindowController) {}

    func showTab(with content: Tab.TabContent) {
        showTabContent = content
    }
}
