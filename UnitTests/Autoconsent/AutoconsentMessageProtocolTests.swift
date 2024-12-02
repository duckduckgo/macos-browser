//
//  AutoconsentMessageProtocolTests.swift
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

import BrowserServicesKit
import Common
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class AutoconsentMessageProtocolTests: XCTestCase {

    @MainActor
    let userScript = AutoconsentUserScript(
        scriptSource: ScriptSourceProvider(configStorage: MockConfigurationStore(),
                                           privacyConfigurationManager: MockPrivacyConfigurationManager(),
                                           webTrackingProtectionPreferences: WebTrackingProtectionPreferences.shared, // mock
                                           contentBlockingManager: ContentBlockerRulesManagerMock(),
                                           trackerDataManager: TrackerDataManager(etag: ConfigurationStore().loadEtag(for: .trackerDataSet),
                                                                                  data: ConfigurationStore().loadData(for: .trackerDataSet),
                                                                                  embeddedDataProvider: AppTrackerDataSetProvider(),
                                                                                  errorReporting: nil),
                                           tld: TLD()),
        config: MockPrivacyConfiguration()
    )

    override func setUp() {
        super.setUp()
        CookiePopupProtectionPreferences.shared.isAutoconsentEnabled = true
    }

    func replyToJson(msg: Any) -> String {
        let jsonData = try? JSONSerialization.data(withJSONObject: msg, options: .sortedKeys)
        return String(data: jsonData!, encoding: .ascii)!
    }

    @MainActor
    func testInitIgnoresNonHttp() {
        let expect = expectation(description: "tt")
        let message = MockWKScriptMessage(name: "init", body: [
            "type": "init",
            "url": "file://helicopter"
        ])
        userScript.handleMessage(
            replyHandler: {(msg: Any?, _: String?) in
                expect.fulfill()
                XCTAssertEqual(self.replyToJson(msg: msg!), """
                {"type":"ok"}
                """)
            },
            message: message
        )
        waitForExpectations(timeout: 1.0)
    }

    @MainActor
    func testInitResponds() {
        let expect = expectation(description: "tt")
        let message = MockWKScriptMessage(name: "init", body: [
            "type": "init",
            "url": "https://example.com"
        ])
        userScript.handleMessage(
            replyHandler: {(msg: Any?, _: String?) in
                expect.fulfill()
                guard let jsonData = try? JSONSerialization.data(withJSONObject: msg!, options: .sortedKeys),
                      let json = try? JSONSerialization.jsonObject(with: jsonData, options: []),
                      let dict = json as? [String: Any],
                      let config = dict["config"] as? [String: Any]
                else {
                    XCTFail("Could not parse init response")
                    return
                }

                XCTAssertEqual(dict["type"] as? String, "initResp")
                XCTAssertEqual(config["autoAction"] as? String, "optOut")
            },
            message: message
        )
        waitForExpectations(timeout: 1.0)
    }

    @MainActor
    func testEval() {
        let message = MockWKScriptMessage(name: "eval", body: [
            "type": "eval",
            "id": "some id",
            "code": "1+1==2"
        ], webView: WKWebView())
        let expect = expectation(description: "testEval")
        userScript.handleMessage(
            replyHandler: {(msg: Any?, _: String?) in
                expect.fulfill()
                XCTAssertEqual(self.replyToJson(msg: msg!), """
                {"id":"some id","result":true,"type":"evalResp"}
                """)
            },
            message: message
        )
        waitForExpectations(timeout: 5.0)
    }

    @MainActor
    func testPopupFoundNoPromptIfEnabled() {
        let expect = expectation(description: "tt")
        let message = MockWKScriptMessage(name: "popupFound", body: [
            "type": "popupFound",
            "cmp": "some cmp",
            "url": "https://example.com"
        ])
        userScript.handleMessage(
            replyHandler: {(msg: Any?, _: String?) in
                expect.fulfill()
                XCTAssertEqual(self.replyToJson(msg: msg!), """
                {"type":"ok"}
                """)
            },
            message: message
        )
        waitForExpectations(timeout: 1.0)
    }
}

class MockWKScriptMessage: WKScriptMessage {

    let mockedName: String
    let mockedBody: Any
    let mockedWebView: WKWebView?

    override var name: String {
        return mockedName
    }

    override var body: Any {
        return mockedBody
    }

    override var webView: WKWebView? {
        return mockedWebView
    }

    init(name: String, body: Any, webView: WKWebView? = nil) {
        self.mockedName = name
        self.mockedBody = body
        self.mockedWebView = webView
        super.init()
    }
}
