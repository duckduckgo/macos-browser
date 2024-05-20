//
//  SSLErrorPageUserScriptTests.swift
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
import UserScript

@testable import DuckDuckGo_Privacy_Browser

final class SSLErrorPageUserScriptTests: XCTestCase {

    var delegate: CapturingSpecialErrorPageUserScriptDelegate!
    var userScript: SpecialErrorPageUserScript!

    override func setUpWithError() throws {
        delegate = CapturingSpecialErrorPageUserScriptDelegate()
        userScript = SpecialErrorPageUserScript()
        userScript.delegate = delegate
    }

    override func tearDownWithError() throws {
        delegate = nil
        userScript = nil
    }

    func test_FeatureHasCorrectName() throws {
        XCTAssertEqual(userScript.featureName, "specialErrorPage")
    }

    func test_BrokerIsCorrectlyAdded() throws {
        // WHEN
        let broker = UserScriptMessageBroker(context: "some contect")
        userScript.with(broker: broker)

        // THEN
        XCTAssertEqual(userScript.broker, broker)
    }

    @MainActor
    func test_WhenHandlerForLeaveSiteCalled_AndIsEnabledFalse_ThenNoHandlerIsReturned() {
        // WHEN
        let handler = userScript.handler(forMethodNamed: "leaveSite")

        // THEN
        XCTAssertNil(handler)
    }

    @MainActor
    func test_WhenHandlerForVisitSiteCalled_AndIsEnabledFalse_ThenNoHandlerIsReturned() {
        // WHEN
        let handler = userScript.handler(forMethodNamed: "visitSite")

        // THEN
        XCTAssertNil(handler)
    }

    @MainActor
    func test_WhenHandlerForLeaveSiteCalled_AndIsEnabledTrue_ThenLeaveSiteCalled() async {
        // GIVEN
        var encodable: Encodable?
        userScript.isEnabled = true

        // WHEN
        let handler = userScript.handler(forMethodNamed: "leaveSite")
        if let handler {
            encodable = try? await handler(Data(), WKScriptMessage())
        }

        // THEN
        XCTAssertNotNil(handler)
        XCTAssertNil(encodable)
        XCTAssertTrue(delegate.leaveSiteCalled)
        XCTAssertFalse(delegate.visitSiteCalled)
    }

    @MainActor
    func test_WhenHandlerForVisitSiteCalled_AndIsEnabledTrue_ThenVisitSiteCalled() async {
        // GIVEN
        var encodable: Encodable?
        userScript.isEnabled = true

        // WHEN
        let handler = userScript.handler(forMethodNamed: "visitSite")
        if let handler {
            encodable = try? await handler(Data(), WKScriptMessage())
        }

        // THEN
        XCTAssertNotNil(handler)
        XCTAssertNil(encodable)
        XCTAssertTrue(delegate.visitSiteCalled)
        XCTAssertFalse(delegate.leaveSiteCalled)
    }

}

class CapturingSpecialErrorPageUserScriptDelegate: SpecialErrorPageUserScriptDelegate {
    var leaveSiteCalled = false
    var visitSiteCalled = false

    func leaveSite() {
        leaveSiteCalled = true
    }

    func visitSite() {
        visitSiteCalled = true
    }
}
