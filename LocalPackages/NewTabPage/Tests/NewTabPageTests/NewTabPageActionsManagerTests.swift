//
//  NewTabPageActionsManagerTests.swift
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
@testable import NewTabPage

final class MockNewTabPageScriptClient: NewTabPageScriptClient {
    var userScriptsSource: NewTabPageUserScriptsSource?

    func registerMessageHandlers(for userScript: SubfeatureWithExternalMessageHandling) {
        registerMessageHandlersCalls.append(userScript)
    }

    var registerMessageHandlersCalls: [SubfeatureWithExternalMessageHandling] = []
}

final class NewTabPageActionsManagerTests: XCTestCase {
    private var actionsManager: NewTabPageActionsManager!

    func testThatUserScriptsReturnsAllRegisteredUserScripts() {
        let actionsManager = NewTabPageActionsManager(scriptClients: [])

        let userScript1 = NewTabPageUserScript()
        let userScript2 = NewTabPageUserScript()
        let userScript3 = NewTabPageUserScript()

        actionsManager.registerUserScript(userScript1)
        actionsManager.registerUserScript(userScript2)
        actionsManager.registerUserScript(userScript3)

        XCTAssertEqual(actionsManager.userScripts.count, 3)
        XCTAssertTrue(actionsManager.userScripts.contains(userScript1))
        XCTAssertTrue(actionsManager.userScripts.contains(userScript2))
        XCTAssertTrue(actionsManager.userScripts.contains(userScript3))
    }

    func testThatDeallocatedUserScriptsAreRemovedFromActionsManager() {
        let actionsManager = NewTabPageActionsManager(scriptClients: [])

        repeat {
            let userScript = NewTabPageUserScript()
            actionsManager.registerUserScript(userScript)
        } while false

        XCTAssertTrue(actionsManager.userScripts.isEmpty)
    }

    func testThatRegisterUserScriptRegistersMessageHandlersForUserScripts() throws {
        let client1 = MockNewTabPageScriptClient()
        let client2 = MockNewTabPageScriptClient()
        let actionsManager = NewTabPageActionsManager(scriptClients: [client1, client2])

        let userScript1 = NewTabPageUserScript()
        let userScript2 = NewTabPageUserScript()

        actionsManager.registerUserScript(userScript1)
        actionsManager.registerUserScript(userScript2)

        XCTAssertEqual(client1.registerMessageHandlersCalls.count, 2)
        XCTAssertIdentical(try XCTUnwrap(client1.registerMessageHandlersCalls[0] as? NewTabPageUserScript), userScript1)
        XCTAssertIdentical(try XCTUnwrap(client1.registerMessageHandlersCalls[1] as? NewTabPageUserScript), userScript2)

        XCTAssertEqual(client2.registerMessageHandlersCalls.count, 2)
        XCTAssertIdentical(try XCTUnwrap(client2.registerMessageHandlersCalls[0] as? NewTabPageUserScript), userScript1)
        XCTAssertIdentical(try XCTUnwrap(client2.registerMessageHandlersCalls[1] as? NewTabPageUserScript), userScript2)
    }
}
