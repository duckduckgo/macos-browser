//
//  TabTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

class TabTests: XCTestCase {

    func testWhenGoForwardIsCalledThenDelegateIsNotified() throws {
        let tab = Tab()
        let tabActionDelegateMock = TabActionDelegateMock()
        tab.actionDelegate = tabActionDelegateMock

        tab.goForward()

        XCTAssertTrue(tabActionDelegateMock.tabForwardActionCalled)
    }

    func testWhenGoBackIsCalledThenDelegateIsNotified() throws {
        let tab = Tab()
        let tabActionDelegateMock = TabActionDelegateMock()
        tab.actionDelegate = tabActionDelegateMock

        tab.goBack()

        XCTAssertTrue(tabActionDelegateMock.tabBackActionCalled)
    }

    func testWhenReloadIsCalledThenDelegateIsNotified() throws {
        let tab = Tab()
        let tabActionDelegateMock = TabActionDelegateMock()
        tab.actionDelegate = tabActionDelegateMock

        tab.reload()

        XCTAssertTrue(tabActionDelegateMock.tabReloadActionCalled)
    }

}
