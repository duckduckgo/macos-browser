//
//  OnboardingTabExtensionTests.swift
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
import Navigation
@testable import DuckDuckGo_Privacy_Browser

final class OnboardingTabExtensionTests: XCTestCase {

    var onboardingTabExtension: OnboardingTabExtension!
    var navigationPreferences: NavigationPreferences!

    override func setUp() {
        super.setUp()
        onboardingTabExtension = OnboardingTabExtension()
        navigationPreferences = NavigationPreferences(userAgent: nil, contentMode: .desktop, javaScriptEnabled: true)
    }

    override func tearDown() {
        navigationPreferences = nil
        onboardingTabExtension = nil
        super.tearDown()
    }

    @MainActor
    func test_WhenNavigatingToOnboardingURL_thenNavigationPolicyIsAllow() async throws {
        // Given
        let navigationAction = NavigationAction(request: URLRequest(url: URL(string: "duck://onboarding://")!), navigationType: .custom(.tabContentUpdate), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: false, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)

        // When
        let navigationPolicy = await onboardingTabExtension.decidePolicy(for: navigationAction, preferences: &navigationPreferences)

        // Then
        XCTAssertEqual(navigationPolicy, .allow)
    }

    @MainActor
    func test_WhenNavigatingNotToOnboardingURL_thenNavigationPolicyIsNext() async throws {
        // Given
        let navigationAction = NavigationAction(request: URLRequest(url: URL(string: "someUrl://")!), navigationType: .custom(.tabContentUpdate), currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: false, sourceFrame: FrameInfo(frame: WKFrameInfo()), targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)

        // When
        let navigationPolicy = await onboardingTabExtension.decidePolicy(for: navigationAction, preferences: &navigationPreferences)

        // Then
        XCTAssertEqual(navigationPolicy, .next)
    }
}

extension NavigationActionPolicy: Equatable {
    public static func == (lhs: NavigationActionPolicy, rhs: NavigationActionPolicy) -> Bool {
        switch (lhs, rhs) {
        case (.allow, .allow), (.cancel, .cancel), (.download, .download), (.redirect, .redirect):
            return true
        default:
            return false
        }
    }
}
