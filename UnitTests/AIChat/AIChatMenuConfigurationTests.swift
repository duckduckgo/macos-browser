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
    var remoteSettings: MockRemoteAISettings!

    override func setUp() {
        super.setUp()
        mockStorage = MockAIChatPreferencesStorage()
        remoteSettings = MockRemoteAISettings()
        configuration = AIChatMenuConfiguration(storage: mockStorage, remoteSettings: remoteSettings)

    }

    override func tearDown() {
        configuration = nil
        mockStorage = nil
        super.tearDown()
    }

    func testShouldDisplayApplicationMenuShortcut() {
        mockStorage.showShortcutInApplicationMenu = true
        let result = configuration.shouldDisplayApplicationMenuShortcut

        XCTAssertTrue(result, "Application menu shortcut should be displayed when enabled.")
    }

    func testShouldDisplayToolbarShortcut() {
        mockStorage.shouldDisplayToolbarShortcut = true
        let result = configuration.shouldDisplayToolbarShortcut

        XCTAssertTrue(result, "Toolbar shortcut should be displayed when enabled.")
    }

    func testToolbarValuesChangedPublisher() {
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

    func testShouldNotDisplayToolbarShortcutWhenDisabled() {
        mockStorage.shouldDisplayToolbarShortcut = false
        let result = configuration.shouldDisplayToolbarShortcut

        XCTAssertFalse(result, "Toolbar shortcut should not be displayed when disabled.")
    }

    func testMarkToolbarOnboardingPopoverAsShown() {
        mockStorage.didDisplayAIChatToolbarOnboarding = false

        configuration.markToolbarOnboardingPopoverAsShown()

        XCTAssertTrue(mockStorage.didDisplayAIChatToolbarOnboarding, "Toolbar onboarding popover should be marked as shown.")
    }

    func testReset() {
        mockStorage.showShortcutInApplicationMenu = true
        mockStorage.shouldDisplayToolbarShortcut = true
        mockStorage.didDisplayAIChatToolbarOnboarding = true

        mockStorage.reset()

        XCTAssertFalse(mockStorage.showShortcutInApplicationMenu, "Application menu shortcut should be reset to false.")
        XCTAssertFalse(mockStorage.shouldDisplayToolbarShortcut, "Toolbar shortcut should be reset to false.")
        XCTAssertFalse(mockStorage.didDisplayAIChatToolbarOnboarding, "Toolbar onboarding popover should be reset to false.")
    }

    func testShouldNotDisplayToolbarShortcutWhenRemoteFlagIsTrueAndStorageIsFalse() {
        remoteSettings.isToolbarShortcutEnabled = true
        mockStorage.shouldDisplayToolbarShortcut = false

        let result = configuration.shouldDisplayToolbarShortcut

        XCTAssertFalse(result, "Toolbar shortcut should not be displayed when remote flag is true and storage is false.")
    }

    func testShouldNotDisplayToolbarShortcutWhenRemoteFlagIsFalseAndStorageIsTrue() {
        remoteSettings.isToolbarShortcutEnabled = false
        mockStorage.shouldDisplayToolbarShortcut = true

        let result = configuration.shouldDisplayToolbarShortcut

        XCTAssertFalse(result, "Toolbar shortcut should not be displayed when remote flag is false, even if storage is true.")
    }

    func testShouldNotDisplayApplicationMenuShortcutWhenRemoteFlagIsTrueAndStorageIsFalse() {
        remoteSettings.isApplicationMenuShortcutEnabled = true
        mockStorage.showShortcutInApplicationMenu = false

        let result = configuration.shouldDisplayApplicationMenuShortcut

        XCTAssertFalse(result, "Application menu shortcut should not be displayed when remote flag is true and storage is false.")
    }

    func testShouldNotDisplayApplicationMenuShortcutWhenRemoteFlagIsFalseAndStorageIsTrue() {
        remoteSettings.isApplicationMenuShortcutEnabled = false
        mockStorage.showShortcutInApplicationMenu = true

        let result = configuration.shouldDisplayApplicationMenuShortcut

        XCTAssertFalse(result, "Application menu shortcut should not be displayed when remote flag is false, even if storage is true.")
    }

    func testShouldDisplayToolbarShortcutWhenRemoteFlagAndStorageAreTrue() {
        remoteSettings.isToolbarShortcutEnabled = true
        mockStorage.shouldDisplayToolbarShortcut = true

        let result = configuration.shouldDisplayToolbarShortcut

        XCTAssertTrue(result, "Toolbar shortcut should be displayed when both remote flag and storage are true.")
    }

    func testShouldDisplayApplicationMenuShortcutWhenRemoteFlagAndStorageAreTrue() {
        remoteSettings.isApplicationMenuShortcutEnabled = true
        mockStorage.showShortcutInApplicationMenu = true

        let result = configuration.shouldDisplayApplicationMenuShortcut

        XCTAssertTrue(result, "Application menu shortcut should be displayed when both remote flag and storage are true.")
    }
}

class MockAIChatPreferencesStorage: AIChatPreferencesStorage {
    var didDisplayAIChatToolbarOnboarding: Bool = false

    func reset() {
        showShortcutInApplicationMenu = false
        shouldDisplayToolbarShortcut = false
        didDisplayAIChatToolbarOnboarding = false
    }

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

    func markToolbarOnboardingPopoverAsShown() { }
}

final class MockRemoteAISettings: AIChatRemoteSettingsProvider {
    var onboardingCookieName: String
    var onboardingCookieDomain: String
    var aiChatURLIdentifiableQuery: String
    var aiChatURLIdentifiableQueryValue: String
    var aiChatURL: URL
    var isAIChatEnabled: Bool
    var isToolbarShortcutEnabled: Bool
    var isApplicationMenuShortcutEnabled: Bool

    init(onboardingCookieName: String = "defaultCookie",
         onboardingCookieDomain: String = "defaultdomain.com",
         aiChatURLIdentifiableQuery: String = "defaultQuery",
         aiChatURLIdentifiableQueryValue: String = "defaultValue",
         aiChatURL: URL = URL(string: "https://duck.com/chat")!,
         isAIChatEnabled: Bool = true,
         isToolbarShortcutEnabled: Bool = true,
         isApplicationMenuShortcutEnabled: Bool = true) {
        self.onboardingCookieName = onboardingCookieName
        self.onboardingCookieDomain = onboardingCookieDomain
        self.aiChatURLIdentifiableQuery = aiChatURLIdentifiableQuery
        self.aiChatURLIdentifiableQueryValue = aiChatURLIdentifiableQueryValue
        self.aiChatURL = aiChatURL
        self.isAIChatEnabled = isAIChatEnabled
        self.isToolbarShortcutEnabled = isToolbarShortcutEnabled
        self.isApplicationMenuShortcutEnabled = isApplicationMenuShortcutEnabled
    }
}
