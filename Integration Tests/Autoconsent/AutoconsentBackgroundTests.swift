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
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 11, *)
class AutoconsentBackgroundTests: XCTestCase {
    
    func testStartupPerformance() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            let expectation = XCTestExpectation(description: "Startup")
            let bg = AutoconsentBackground()
            bg.ready {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
    }

    func testAutoconsentIsCreated() {
        let bg = AutoconsentBackground()
        let expectation = XCTestExpectation(description: "Async call")
        bg.ready {
            bg.background.evaluateJavaScript("typeof window.autoconsent", in: nil, in: .page, completionHandler: { result in
                switch result {
                case .success(let value as String):
                    XCTAssertEqual(value, "object", "window.autoconsent should be an object")
                case .success:
                    XCTFail("Failed to check for autoconsent global")
                case .failure:
                    XCTFail("Failed to check for autoconsent global")
                }
                expectation.fulfill()
            })
        }
        wait(for: [expectation], timeout: 2)
    }
    
    func testUserscriptIntegration() {
        // enable the feature
        let prefs = PrivacySecurityPreferences.shared
        prefs.autoconsentEnabled = true
        // setup a webview with autoconsent userscript installed
        let autoconsentUserScript = AutoconsentUserScript(scriptSource: DefaultScriptSourceProvider(),
                                                          config: ContentBlocking.shared.privacyConfigurationManager.privacyConfig)
        let configuration = WKWebViewConfiguration()

        configuration.userContentController.addUserScript(autoconsentUserScript.makeWKUserScript())
        configuration.userContentController.addHandler(autoconsentUserScript)
        let webview = WKWebView(frame: .zero, configuration: configuration)
        let expectation = XCTestExpectation(description: "Async call")
        let url = Bundle(for: type(of: self)).url(forResource: "autoconsent-test-page", withExtension: "html")!
        webview.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            webview.evaluateJavaScript("results.results[0] === 'button_clicked'", in: nil, in: .page, completionHandler: { result in
                switch result {
                case .success(let value as Bool):
                    XCTAssertTrue(value, "Button should have been clicked")
                case .success:
                    XCTFail("Failed to read test result")
                case .failure:
                    XCTFail("Failed to read test result")
                }
                expectation.fulfill()
            })
        }
        wait(for: [expectation], timeout: 4)
    }

}
