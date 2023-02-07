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
    struct URLs {
        let ddg = URL.duckDuckGo
        let ddgSearch = URL.makeSearchUrl(from: "some search query")
        let ddg2 = URL.duckDuckGoEmail
        let ddg3 = URL.duckDuckGoAutocomplete

        let ddg5 = URL.aboutDuckDuckGo
        let ddg7 = URL.privacyPolicy

        let someUrl = URL(string: "https://youtube.com/")!
        let privacy_ddg = URL.duckDuckGoMorePrivacyInfo
        let gpc_ddg = URL.gpcLearnMore
    }
    struct DataSource {
        let empty = Data()
        let html = """
            <html>
                <body>
                    some data
                    <a id="navlink" />
                </body>
            </html>
        """.data(using: .utf8)!
        let metaRedirect = """
        <html>
            <head>
                <meta http-equiv="Refresh" content="0; URL=http://localhost:8084/3" />
            </head>
        </html>
        """.data(using: .utf8)!
    }

    let urls = URLs()
    let data = DataSource()

    override func setUp() {
        // disable waiting for CBR compilation on navigation
        MockPrivacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }
    }

    override func tearDown() async throws {
        TestTabExtensionsBuilder.shared = .default
        MockPrivacyConfiguration.isFeatureKeyEnabled = nil
    }

    // MARK: - Tests

    @MainActor
    func testOnDDGRequest_headersAdded() {
        var onNavAction: (@MainActor (NavigationAction) -> NavigationActionPolicy?)!
        TestTabExtensionsBuilder.shared = TestTabExtensionsBuilder(load: []) { builder in { _, _ in
            builder.add {
                TestsClosureNavigationResponderTabExtension(.init { navigationAction, _ in
                    onNavAction(navigationAction)
                })
            }
        }}

        let tab = Tab(content: .none, shouldLoadInBackground: true)

        for child in Mirror(reflecting: urls).children.filter({ $0.label!.hasPrefix("ddg") }) {
            let url = child.value as! URL

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
            waitForExpectations(timeout: 50)
            tab.stopLoading()
        }
    }

    @MainActor
    func testOnRegularRequest_headersNotAdded() {
        var onNavAction: (@MainActor (NavigationAction) -> NavigationActionPolicy?)!
        TestTabExtensionsBuilder.shared = TestTabExtensionsBuilder(load: []) { builder in { _, _ in
            builder.add {
                TestsClosureNavigationResponderTabExtension(.init { navigationAction, _ in
                    onNavAction(navigationAction)
                })
            }
        }}

        let tab = Tab(content: .none, shouldLoadInBackground: true)

        for child in Mirror(reflecting: urls).children.filter({ !$0.label!.hasPrefix("ddg") }) {
            let url = child.value as! URL

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
            waitForExpectations(timeout: 50)
            tab.stopLoading()
        }
    }

}
