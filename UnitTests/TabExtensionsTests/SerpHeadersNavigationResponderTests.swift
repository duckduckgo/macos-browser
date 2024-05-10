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

@available(macOS 12.0, *)
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

    var webViewConfiguration: WKWebViewConfiguration!
    var schemeHandler: TestSchemeHandler!

    override func setUp() {
        contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }

        schemeHandler = TestSchemeHandler()
        WKWebView.customHandlerSchemes = [.http, .https]
        webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.http.rawValue)
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.https.rawValue)
    }

    override func tearDown() {
        contentBlockingMock = nil
        privacyFeaturesMock = nil
        schemeHandler = nil
        WKWebView.customHandlerSchemes = []
    }

    // MARK: - Tests

    @MainActor
    func testOnDDGRequest_headersAdded() {
        for url in ddgUrls {
            let eRequestReceived = expectation(description: "Request received for \(url.absoluteString)")
            let eDidFinish = expectation(description: "Navigation did finish for \(url.absoluteString)")
            let extensionsBuilder = TestTabExtensionsBuilder(load: []) { builder in { _, _ in
                builder.add {
                    TestsClosureNavigationResponderTabExtension(.init(navigationDidFinish: { _ in
                        eDidFinish.fulfill()
                    }))
                }
            }}
            let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)

            schemeHandler.middleware = [{ request in
                XCTAssertEqual(request.url, url)
                for (key, value) in SerpHeadersNavigationResponder.headers {
                    XCTAssertEqual(request.value(forHTTPHeaderField: key), value, "for " + url.absoluteString)
                }

                eRequestReceived.fulfill()
                return .ok(.html(""))
            }]

            tab.setContent(.url(url, source: .link))
            waitForExpectations(timeout: 5)
            tab.stopLoading()
        }
    }

    @MainActor
    func testOnRegularRequest_headersNotAdded() {
        for url in nonDdgUrls {
            let eRequestReceived = expectation(description: "Request received for \(url.absoluteString)")
            let eDidFinish = expectation(description: "Navigation did finish for \(url.absoluteString)")
            let extensionsBuilder = TestTabExtensionsBuilder(load: []) { builder in { _, _ in
                builder.add {
                    TestsClosureNavigationResponderTabExtension(.init(navigationDidFinish: { _ in
                        eDidFinish.fulfill()
                    }))
                }
            }}
            let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)

            schemeHandler.middleware = [{ request in
                XCTAssertEqual(request.url, url)
                for (key, _) in SerpHeadersNavigationResponder.headers {
                    XCTAssertNil(request.value(forHTTPHeaderField: key), "for " + url.absoluteString)
                }

                eRequestReceived.fulfill()
                return .ok(.html(""))
            }]

            tab.setContent(.url(url, source: .link))
            waitForExpectations(timeout: 5)
            tab.stopLoading()
        }
    }

}
