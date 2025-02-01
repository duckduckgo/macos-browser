//
//  WebExtensionManagerTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 14.4, *)
final class WebExtensionManagerTests: XCTestCase {

    var pathsCachingMock: WebExtensionPathsCachingMock!
    var webExtensionLoadingMock: WebExtensionLoadingMock!
    var internalUserStore = MockInternalUserStoring()
    var featureFlaggerMock: MockFeatureFlagger!

    override func setUp() {
        super.setUp()

        pathsCachingMock = WebExtensionPathsCachingMock()
        webExtensionLoadingMock = WebExtensionLoadingMock()
        featureFlaggerMock = MockFeatureFlagger()
        featureFlaggerMock.internalUserDecider = DefaultInternalUserDecider(store: internalUserStore)
        internalUserStore.isInternalUser = true
    }

    override func tearDown() {
        pathsCachingMock = nil
        webExtensionLoadingMock = nil
        featureFlaggerMock = nil

        super.tearDown()
    }

    func testWhenExtensionIsAdded_ThenPathIsCached() {
        let webExtensionManager = WebExtensionManager(
            webExtensionPathsCache: pathsCachingMock,
            webExtensionLoader: webExtensionLoadingMock,
            internalUserDecider: featureFlaggerMock.internalUserDecider,
            featureFlagger: featureFlaggerMock
        )

        let path = "/path/to/extension"
        webExtensionManager.addExtension(path: path)
        XCTAssertTrue(pathsCachingMock.addCalled)
        XCTAssertEqual(pathsCachingMock.addedURL, path)
    }

    func testWhenExtensionIsRemoved_ThenPathIsRemovedFromCache() {
        let webExtensionManager = WebExtensionManager(
            webExtensionPathsCache: pathsCachingMock,
            webExtensionLoader: webExtensionLoadingMock,
            internalUserDecider: featureFlaggerMock.internalUserDecider,
            featureFlagger: featureFlaggerMock
        )

        let path = "/path/to/extension"
        webExtensionManager.removeExtension(path: path)
        XCTAssertTrue(pathsCachingMock.removeCalled)
        XCTAssertEqual(pathsCachingMock.removedURL, path)
    }

    func testWhenWebExtensionsAreLoaded_ThenPathsAreFetchedFromCache() {
        let paths = ["/path/to/extension1", "/path/to/extension2"]
        pathsCachingMock.cache = paths

        let webExtensionManager = WebExtensionManager(
            webExtensionPathsCache: pathsCachingMock,
            webExtensionLoader: webExtensionLoadingMock,
            internalUserDecider: featureFlaggerMock.internalUserDecider,
            featureFlagger: featureFlaggerMock
        )

        XCTAssertTrue(webExtensionLoadingMock.loadWebExtensionsCalled)
        XCTAssertEqual(webExtensionLoadingMock.loadedPaths, paths)
    }

    func testThatWebExtensionPaths_ReturnsPathsFromCache() {
        let webExtensionManager = WebExtensionManager(
            webExtensionPathsCache: pathsCachingMock,
            webExtensionLoader: webExtensionLoadingMock,
            internalUserDecider: featureFlaggerMock.internalUserDecider,
            featureFlagger: featureFlaggerMock
        )

        let paths = ["/path/to/extension1", "/path/to/extension2"]
        pathsCachingMock.cache = paths
        let resultPaths = webExtensionManager.webExtensionPaths
        XCTAssertEqual(resultPaths, paths)
    }

    func testWhenExtensionsAreEnabled_ThenFeatureFlagAndInternalUserStatusAreChecked() {
        featureFlaggerMock.isFeatureOn = true
        internalUserStore.isInternalUser = true

        let webExtensionManager = WebExtensionManager(
            webExtensionPathsCache: pathsCachingMock,
            webExtensionLoader: webExtensionLoadingMock,
            internalUserDecider: featureFlaggerMock.internalUserDecider,
            featureFlagger: featureFlaggerMock
        )

        XCTAssertTrue(webExtensionManager.areExtenstionsEnabled)
    }

    func testWhenExtensionsAreDisabled_ThenLoadWebExtensionsDoesNothing() {
        featureFlaggerMock.isFeatureOn = false
        internalUserStore.isInternalUser = true

        let webExtensionManager = WebExtensionManager(
            webExtensionPathsCache: pathsCachingMock,
            webExtensionLoader: webExtensionLoadingMock,
            internalUserDecider: featureFlaggerMock.internalUserDecider,
            featureFlagger: featureFlaggerMock
        )

        XCTAssertFalse(webExtensionManager.areExtenstionsEnabled)
        XCTAssertFalse(webExtensionLoadingMock.loadWebExtensionsCalled)
        XCTAssertTrue(webExtensionManager.extensions.isEmpty)
    }

    func testWhenUserIsNotInternal_ThenLoadWebExtensionsDoesNothing() {
        featureFlaggerMock.isFeatureOn = true
        internalUserStore.isInternalUser = false

        let webExtensionManager = WebExtensionManager(
            webExtensionPathsCache: pathsCachingMock,
            webExtensionLoader: webExtensionLoadingMock,
            internalUserDecider: featureFlaggerMock.internalUserDecider,
            featureFlagger: featureFlaggerMock
        )

        XCTAssertFalse(webExtensionManager.areExtenstionsEnabled)
        XCTAssertFalse(webExtensionLoadingMock.loadWebExtensionsCalled)
        XCTAssertTrue(webExtensionManager.extensions.isEmpty)
    }
}
