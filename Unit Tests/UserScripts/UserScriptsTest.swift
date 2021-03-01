//
//  UserScriptsTest.swift
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

import Foundation
import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

class UserScriptsTests: XCTestCase {

    func testUserScriptsScriptsAreInitializedOnce() {
        let userScripts = UserScripts()

        let scripts1 = Set(userScripts.scripts)
        let scripts2 = Set(userScripts.scripts)

        XCTAssertFalse(scripts1.isEmpty)
        XCTAssertEqual(scripts1, scripts2)
    }

    func testWhenUserScriptsCopiedScriptsAreNotReloaded() {
        let userScripts1 = UserScripts()
        let userScripts2 = UserScripts(copy: userScripts1)

        let scripts1 = Set(userScripts1.scripts)
        let scripts2 = Set(userScripts2.scripts)

        // swiftlint:disable force_cast
        let set1 = Set(userScripts1.userScripts as! [NSObject])
        let set2 = Set(userScripts2.userScripts as! [NSObject])
        // swiftlint:enable force_cast

        XCTAssertEqual(scripts1, scripts2)
        XCTAssertNotEqual(set1, set2)
    }

    func testWhenUserScriptsInitializedScriptsAreReloaded() {
        let userScripts1 = UserScripts()
        let userScripts2 = UserScripts()

        let scripts1 = Set(userScripts1.scripts)
        let scripts2 = Set(userScripts2.scripts)

        // swiftlint:disable force_cast
        let set1 = Set(userScripts1.userScripts as! [NSObject])
        let set2 = Set(userScripts2.userScripts as! [NSObject])
        // swiftlint:enable force_cast

        XCTAssertNotEqual(scripts1, scripts2)
        XCTAssertNotEqual(set1, set2)
    }

    func testWhenUserScriptsInstalledScriptsAndHandlersAreInstalled() {
        let userScripts = UserScripts()

        let scripts = Set(userScripts.scripts)
        let messageHandlersCount = userScripts.userScripts.reduce(0) { $0 + $1.messageNames.count }

        let e = expectation(description: "Should receive message")
        let instrumentation = TabInstrumentationMock {
            XCTAssertEqual($0, "test")
            XCTAssertEqual($1, 0.1)
            e.fulfill()
        }

        let userContentController = UserContentControllerMock()
        userScripts.debugScript.instrumentation = instrumentation
        userScripts.install(into: userContentController)

        let message = WKScriptMessageMock(name: DebugUserScript.MessageNames.signpost.rawValue,
                                          body: ["event": "Generic",
                                                 "name": "test",
                                                 "time": 0.1])
        userContentController.handlers["signpost"]!.userContentController(WKUserContentController(),
                                                                          didReceive: message)

        let installedScripts = Set(userContentController.userScripts)

        XCTAssertEqual(scripts, installedScripts)
        XCTAssertEqual(messageHandlersCount, userContentController.handlers.count)
        waitForExpectations(timeout: 0.3)
    }

    func testWhenUserScriptsRemovedInOneWebViewThenScriptsStayInOtherWebView() {
        let webView1 = WebView(frame: .zero, configuration: .makeConfiguration())
        let webView2 = WebView(frame: .zero, configuration: .makeConfiguration())

        let userScripts1 = UserScripts()
        let userScripts2 = UserScripts(copy: userScripts1)

        userScripts1.install(into: webView1.configuration.userContentController)
        userScripts2.install(into: webView2.configuration.userContentController)

        userScripts1.remove(from: webView1.configuration.userContentController)

        XCTAssertTrue(webView1.configuration.userContentController.userScripts.isEmpty)
        XCTAssertEqual(webView2.configuration.userContentController.userScripts, userScripts2.scripts)
    }

    func testWhenUserScriptsRemovedCanBeReinstalled() {
        let webView = WebView(frame: .zero, configuration: .makeConfiguration())
        let userScripts1 = UserScripts()
        userScripts1.install(into: webView.configuration.userContentController)
        userScripts1.remove(from: webView.configuration.userContentController)

        let userScripts2 = UserScripts()
        userScripts2.install(into: webView.configuration.userContentController)

        XCTAssertEqual(webView.configuration.userContentController.userScripts, userScripts2.scripts)
    }

}

extension UserScriptsTests {

    final class TabInstrumentationMock: TabInstrumentationProtocol {
        let callback: (String, Double) -> Void

        init(callback: @escaping (String, Double) -> Void) {
            self.callback = callback
        }

        func request(url: String, allowedIn timeInMs: Double) {
        }
        func tracker(url: String, allowedIn timeInMs: Double, reason: String?) {
        }
        func tracker(url: String, blockedIn timeInMs: Double) {
        }

        func jsEvent(name: String, executedIn timeInMs: Double) {
            callback(name, timeInMs)
        }
    }

    final class UserContentControllerMock: UserScripting {
        var userScripts = [WKUserScript]()
        var handlers = [String: WKScriptMessageHandler]()

        func addUserScript(_ userScript: WKUserScript) {
            userScripts.append(userScript)
        }

        func removeAllUserScripts() {
            userScripts = []
        }

        func add(_ scriptMessageHandler: WKScriptMessageHandler, name: String) {
            assert(handlers[name] == nil)
            handlers[name] = scriptMessageHandler
        }
        @available(OSX 11.0, *)
        func add(_ scriptMessageHandler: WKScriptMessageHandler, contentWorld world: WKContentWorld, name: String) {
            add(scriptMessageHandler, name: name)
        }

        func removeScriptMessageHandler(forName name: String) {
            handlers[name] = nil
        }
        @available(OSX 11.0, *)
        func removeScriptMessageHandler(forName name: String, contentWorld: WKContentWorld) {
            removeScriptMessageHandler(forName: name)
        }
    }

    final class WKScriptMessageMock: WKScriptMessage {
        // swiftlint:disable identifier_name
        var _name: String
        var _body: Any
        // swiftlint:enable identifier_name
        override var name: String { _name }
        override var body: Any { _body }

        init(name: String, body: Any) {
            self._name = name
            self._body = body
        }
    }

}
