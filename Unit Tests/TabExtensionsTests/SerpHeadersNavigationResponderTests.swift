//
//  SerpHeadersNavigationResponderTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Navigation
import WebKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class SerpHeadersNavigationResponderTests: XCTestCase {

    let ddgUrls = [
        URL.duckDuckGo,
        URL.makeSearchUrl(from: "some search query")!,
        URL.duckDuckGoEmail,
        URL.duckDuckGoAutocomplete,

        URL.aboutDuckDuckGo,
        URL.privacyPolicy,
    ]

    let nonDdgUrls = [
        URL(string: "https://duckduckgo.com.local/")!,
        URL(string: "https://my.duckduckgo.com/")!,
        URL(string: "https://youtube.com/")!,

        URL.duckDuckGoMorePrivacyInfo,
        URL.gpcLearnMore,
    ]

    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }

    override func setUp() {
        contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }
    }

    override func tearDown() {
        contentBlockingMock = nil
        privacyFeaturesMock = nil
    }

    // MARK: - Tests

    @MainActor
    func testOnDDGRequest_headersAdded() {
        var onNavAction: (@MainActor (NavigationAction) -> NavigationActionPolicy?)!
        let extensionsBuilder = TestTabExtensionsBuilder(load: []) { builder in { _, _ in
            builder.add {
                TestsClosureNavigationResponderTabExtension(.init { navigationAction, _ in
                    onNavAction(navigationAction)
                })
            }
        }}
        let tab = Tab(content: .none, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)

        for url in ddgUrls {
            let eNavAction = expectation(description: "onNavAction for \(url.absoluteString)")
            onNavAction = { navigationAction in
                XCTAssertEqual(navigationAction.url, url)
                for (key, value) in SerpHeadersNavigationResponder.headers {
                    XCTAssertEqual(navigationAction.request.value(forHTTPHeaderField: key), value, "for " + url.absoluteString)
                }

                eNavAction.fulfill()

                return .cancel
            }

            print(url)
            tab.setContent(.url(url))
            waitForExpectations(timeout: 5)
            tab.stopLoading()
        }
    }

    @MainActor
    func testOnRegularRequest_headersNotAdded() {
        var onNavAction: (@MainActor (NavigationAction) -> NavigationActionPolicy?)!
        let extensionsBuilder = TestTabExtensionsBuilder(load: []) { builder in { _, _ in
            builder.add {
                TestsClosureNavigationResponderTabExtension(.init { navigationAction, _ in
                    onNavAction(navigationAction)
                })
            }
        }}

        let tab = Tab(content: .none, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)

        for url in nonDdgUrls {
            let eNavAction = expectation(description: "onNavAction for \(url.absoluteString)")
            onNavAction = { navigationAction in
                XCTAssertEqual(navigationAction.url, url)
                for (key, _) in SerpHeadersNavigationResponder.headers {
                    XCTAssertNil(navigationAction.request.value(forHTTPHeaderField: key), "for " + url.absoluteString)
                }

                eNavAction.fulfill()

                return .cancel
            }

            print(url)
            tab.setContent(.url(url))
            waitForExpectations(timeout: 5)
            tab.stopLoading()
        }
    }

}
