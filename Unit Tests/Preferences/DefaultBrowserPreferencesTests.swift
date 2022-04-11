//
//  DefaultBrowserPreferencesTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

private struct MockError: Error {}

final class DefaultBrowserPreferencesTests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional
    var provider: DefaultBrowserProviderMock!

    override func setUpWithError() throws {
        provider = DefaultBrowserProviderMock()
        provider.isDefault = true
        provider.bundleIdentifier = "com.duckduckgo.macos.browser.DefaultBrowserPreferencesTests"
    }

    func testWhenInitializedThenIsDefaultIsTakenFromProvider() throws {
        provider.isDefault = true
        XCTAssertTrue(DefaultBrowserPreferences(defaultBrowserProvider: provider).isDefault)

        provider.isDefault = false
        XCTAssertFalse(DefaultBrowserPreferences(defaultBrowserProvider: provider).isDefault)
    }

    func testWhenCheckIfDefaultIsCalledThenValueIsUpdatedFromProvider() throws {
        provider.isDefault = false
        let model = DefaultBrowserPreferences(defaultBrowserProvider: provider)
        provider.isDefault = true

        XCTAssertNotEqual(model.isDefault, provider.isDefault)

        model.checkIfDefault()
        XCTAssertEqual(model.isDefault, provider.isDefault)
    }

    func testWhenBecomeDefaultIsCalledThenDefaultBrowserPromptIsRequested() throws {
        let model = DefaultBrowserPreferences(defaultBrowserProvider: provider)

        model.becomeDefault()
        XCTAssertEqual(provider.presentDefaultBrowserPromptCallsCount, 1)
        XCTAssertFalse(provider.openSystemPreferencesCalled)
    }

    func testWhenDefaultBrowserPromptFailsThenPreferencesAreOpened() throws {
        let model = DefaultBrowserPreferences(defaultBrowserProvider: provider)

        provider.presentDefaultBrowserPromptThrowableError = MockError()

        model.becomeDefault()

        XCTAssertEqual(provider.presentDefaultBrowserPromptCallsCount, 1)
        XCTAssertEqual(provider.openSystemPreferencesCallsCount, 1)
    }
}
