//
//  AIChatMenuConfigurationTests.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

class AIChatMenuConfigurationTests: XCTestCase {
    var configuration: AIChatMenuConfiguration!
    var mockStorage: MockAIChatPreferencesStorage!

    override func setUp() {
        super.setUp()
        mockStorage = MockAIChatPreferencesStorage()
        configuration = AIChatMenuConfiguration(storage: mockStorage)
    }

    override func tearDown() {
        configuration = nil
        mockStorage = nil
        super.tearDown()
    }

    func testShouldDisplayApplicationMenuShortcut() {
        mockStorage.showShortcutInApplicationMenu = true
        let featureEnabled = true

        let result = configuration.shouldDisplayApplicationMenuShortcut

        XCTAssertTrue(result, "Application menu shortcut should be displayed when enabled.")
    }

    func testShouldDisplayToolbarShortcut() {
        mockStorage.shouldDisplayToolbarShortcut = true
        let featureEnabled = true
        let result = configuration.shouldDisplayToolbarShortcut

        XCTAssertTrue(result, "Toolbar shortcut should be displayed when enabled.")
    }

    func testShortcutURL() {
        let url = configuration.shortcutURL

        XCTAssertEqual(url.absoluteString, "https://duckduckgo.com/?q=DuckDuckGo+AI+Chat&ia=chat&duckai=2", "Shortcut URL should match the expected URL.")
    }

    func testToolbarValuesChangedPublisher() {
        // Given
        let expectation = self.expectation(description: "Values changed publisher should emit a value.")
        var receivedValue: Void?

        let cancellable = configuration.valuesChangedPublisher.sink {
            receivedValue = $0
            expectation.fulfill()
        }

        mockStorage.updateToolbarShortcutDisplay(to: true)

        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Values changed publisher did not emit a value in time.")
            XCTAssertNotNil(receivedValue, "Values changed publisher should emit a value when storage changes.")
        }
        cancellable.cancel()
    }
    
    func testApplicationMenuValuesChangedPublisher() {
        let expectation = self.expectation(description: "Values changed publisher should emit a value.")
        var receivedValue: Void?

        let cancellable = configuration.valuesChangedPublisher.sink {
            receivedValue = $0
            expectation.fulfill()
        }

        mockStorage.updateApplicationMenuShortcutDisplay(to: true)

        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error, "Values changed publisher did not emit a value in time.")
            XCTAssertNotNil(receivedValue, "Values changed publisher should emit a value when storage changes.")
        }
        cancellable.cancel()
    }
}

class MockAIChatPreferencesStorage: AIChatPreferencesStorage {
    var showShortcutInApplicationMenu: Bool = false {
        didSet {
            showShortcutInApplicationMenuSubject.send(showShortcutInApplicationMenu)
        }
    }
    
    var shouldDisplayToolbarShortcut: Bool = false {
        didSet {
            shouldDisplayToolbarShortcutSubject.send(shouldDisplayToolbarShortcut)
        }
    }
    
    private var showShortcutInApplicationMenuSubject = PassthroughSubject<Bool, Never>()
    private var shouldDisplayToolbarShortcutSubject = PassthroughSubject<Bool, Never>()

    var showShortcutInApplicationMenuPublisher: AnyPublisher<Bool, Never> {
        showShortcutInApplicationMenuSubject.eraseToAnyPublisher()
    }

    var shouldDisplayToolbarShortcutPublisher: AnyPublisher<Bool, Never> {
        shouldDisplayToolbarShortcutSubject.eraseToAnyPublisher()
    }

    func updateApplicationMenuShortcutDisplay(to value: Bool) {
        showShortcutInApplicationMenu = value
    }

    func updateToolbarShortcutDisplay(to value: Bool) {
        shouldDisplayToolbarShortcut = value
    }
}
