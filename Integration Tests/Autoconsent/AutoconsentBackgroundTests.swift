//
//  AutoconsentBackgroundTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Common
import BrowserServicesKit
import TrackerRadarKit
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 11, *)
class AutoconsentBackgroundTests: XCTestCase {
    // todo: mock
    let preferences = PrivacySecurityPreferences.shared

    func testUserscriptIntegration() {
        // enable the feature
        let prefs = PrivacySecurityPreferences.shared
        prefs.autoconsentEnabled = true
        // setup a webview with autoconsent userscript installed
        let sourceProvider = ScriptSourceProvider(configStorage: MockStorage(),
                                                  privacyConfigurationManager: MockPrivacyConfigurationManager(),
                                                  privacySettings: preferences,
                                                  contentBlockingManager: ContentBlockerRulesManagerMock(),
                                                  trackerDataManager: TrackerDataManager(etag: DefaultConfigurationStorage.shared.loadEtag(for: .trackerRadar),
                                                                                         data: DefaultConfigurationStorage.shared.loadData(for: .trackerRadar),
                                                                                         embeddedDataProvider: AppTrackerDataSetProvider(),
                                                                                         errorReporting: nil),

                                                  tld: TLD())
        let autoconsentUserScript = AutoconsentUserScript(scriptSource: sourceProvider,
                                                          config: MockPrivacyConfigurationManager().privacyConfig)
        let configuration = WKWebViewConfiguration()

        configuration.userContentController.addUserScript(autoconsentUserScript.makeWKUserScript())
        configuration.userContentController.addHandler(autoconsentUserScript)

        let webview = WKWebView(frame: .zero, configuration: configuration)
        let navigationDelegate = TestNavigationDelegate(e: expectation(description: "WebView Did finish navigation"))
        webview.navigationDelegate = navigationDelegate
        let url = Bundle(for: type(of: self)).url(forResource: "autoconsent-test-page", withExtension: "html")!
        webview.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        waitForExpectations(timeout: 1)

        let expectation = expectation(description: "Async call")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            webview.evaluateJavaScript("results.results.includes('button_clicked')", in: nil, in: .page,
                                       completionHandler: { result in
                switch result {
                case .success(let value as Bool):
                    XCTAssertTrue(value, "Button should have been clicked once")
                case .success:
                    XCTFail("Failed to read test result")
                case .failure:
                    XCTFail("Failed to read test result")
                }
                expectation.fulfill()
            })
        }
        waitForExpectations(timeout: 4)
    }
}

class MockStorage: ConfigurationStoring {

    enum Error: Swift.Error {
        case mockError
    }

    var errorOnStoreData = false
    var errorOnStoreEtag = false

    var data: Data?
    var dataConfig: ConfigurationLocation?

    var etag: String?
    var etagConfig: ConfigurationLocation?

    func loadData(for: ConfigurationLocation) -> Data? {
        return data
    }

    func loadEtag(for: ConfigurationLocation) -> String? {
        return etag
    }

    func saveData(_ data: Data, for config: ConfigurationLocation) throws {
        if errorOnStoreData {
            throw Error.mockError
        }

        self.data = data
        self.dataConfig = config
    }

    func saveEtag(_ etag: String, for config: ConfigurationLocation) throws {
        if errorOnStoreEtag {
            throw Error.mockError
        }

        self.etag = etag
        self.etagConfig = config
    }

    func log() { }

}
