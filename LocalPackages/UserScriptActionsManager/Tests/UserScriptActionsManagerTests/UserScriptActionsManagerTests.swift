//
//  UserScriptActionsManagerTests.swift
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
import WebKit
@testable import UserScriptActionsManager

final class MockUserScript: SubfeatureWithExternalMessageHandling, Equatable {
    static func == (lhs: MockUserScript, rhs: MockUserScript) -> Bool {
        lhs === rhs
    }

    var webView: WKWebView?
    func registerMessageHandlers(_ handlers: [String: (Any, WKScriptMessage) async throws -> (any Encodable)?]) {}
    func handler(forMethodNamed methodName: String) -> Handler? { return nil }
    var messageOriginPolicy: MessageOriginPolicy = .all
    var featureName: String = "mock"
    var broker: UserScriptMessageBroker?
}

final class MockUserScriptClient: UserScriptClient {
    typealias Script = MockUserScript
    var actionsManager: (any UserScriptActionsManaging)?

    func registerMessageHandlers(for userScript: MockUserScript) {
        registerMessageHandlersCalls.append(userScript)
    }

    var registerMessageHandlersCalls: [MockUserScript] = []
}

final class TestActionsManager: UserScriptActionsManager<MockUserScript, MockUserScriptClient> {}

final class UserScriptActionsManagerTests: XCTestCase {
    private var actionsManager: TestActionsManager!

    func testThatUserScriptsReturnsAllRegisteredUserScripts() {
        let actionsManager = TestActionsManager(scriptClients: [])

        let userScript1 = MockUserScript()
        let userScript2 = MockUserScript()
        let userScript3 = MockUserScript()

        actionsManager.registerUserScript(userScript1)
        actionsManager.registerUserScript(userScript2)
        actionsManager.registerUserScript(userScript3)

        XCTAssertEqual(actionsManager.userScripts.count, 3)
        XCTAssertTrue(actionsManager.userScripts.contains(userScript1))
        XCTAssertTrue(actionsManager.userScripts.contains(userScript2))
        XCTAssertTrue(actionsManager.userScripts.contains(userScript3))
    }

    func testThatDeallocatedUserScriptsAreRemovedFromActionsManager() {
        let actionsManager = TestActionsManager(scriptClients: [])

        repeat {
            let userScript = MockUserScript()
            actionsManager.registerUserScript(userScript)
        } while false

        XCTAssertTrue(actionsManager.userScripts.isEmpty)
    }

    func testThatRegisterUserScriptRegistersMessageHandlersForUserScripts() throws {
        let client1 = MockUserScriptClient()
        let client2 = MockUserScriptClient()
        let actionsManager = TestActionsManager(scriptClients: [client1, client2])

        let userScript1 = MockUserScript()
        let userScript2 = MockUserScript()

        actionsManager.registerUserScript(userScript1)
        actionsManager.registerUserScript(userScript2)

        XCTAssertEqual(client1.registerMessageHandlersCalls.count, 2)
        XCTAssertIdentical(try XCTUnwrap(client1.registerMessageHandlersCalls[0]), userScript1)
        XCTAssertIdentical(try XCTUnwrap(client1.registerMessageHandlersCalls[1]), userScript2)

        XCTAssertEqual(client2.registerMessageHandlersCalls.count, 2)
        XCTAssertIdentical(try XCTUnwrap(client2.registerMessageHandlersCalls[0]), userScript1)
        XCTAssertIdentical(try XCTUnwrap(client2.registerMessageHandlersCalls[1]), userScript2)
    }
}
