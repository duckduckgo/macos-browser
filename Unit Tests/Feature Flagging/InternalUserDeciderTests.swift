//
//  InternalUserDeciderTests.swift
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

import Foundation
import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class InternalUserDeciderTests: XCTestCase {

    func testWhenURLAndStatusCodeCorrect_ThenIsInternalAndStoreSaved() {
        let store = InternalUserDeciderStoreMock()
        let internalUserDecider = InternalUserDecider(store: store)

        let url = URL(string: "http://use-login.duckduckgo.com")!
        let httpUrlResponse = HTTPURLResponse(url: url,
                                              statusCode: 200,
                                              httpVersion: nil,
                                              headerFields: nil)
        internalUserDecider.markUserAsInternalIfNeeded(forUrl: url, response: httpUrlResponse)
        XCTAssert(internalUserDecider.isInternalUser)
        XCTAssert(store.saveCalled)
        XCTAssert(store.isInternal)
    }

    func testWhenURLAndStatusCodeIncorrect_ThenReturnsFalse() {
        let store = InternalUserDeciderStoreMock()
        let internalUserDecider = InternalUserDecider(store: store)

        let url1 = URL(string: "http://duckduckgo.com")!
        let httpUrlResponse1 = HTTPURLResponse(url: url1,
                                               statusCode: 200,
                                               httpVersion: nil,
                                               headerFields: nil)
        internalUserDecider.markUserAsInternalIfNeeded(forUrl: url1, response: httpUrlResponse1)
        XCTAssertFalse(internalUserDecider.isInternalUser)

        let url2 = URL(string: "http://use-login.duckduckgo.com")!
        let httpUrlResponse2 = HTTPURLResponse(url: url2,
                                               statusCode: 500,
                                               httpVersion: nil,
                                               headerFields: nil)
        internalUserDecider.markUserAsInternalIfNeeded(forUrl: url2, response: httpUrlResponse2)
        XCTAssertFalse(internalUserDecider.isInternalUser)
    }

    func testWhenInitialized_ThenStoreLoadCalled() {
        let store = InternalUserDeciderStoreMock()
        let _ = InternalUserDecider(store: store)

        XCTAssert(store.loadCalled)
    }

}
