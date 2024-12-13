//
//  NewTabPageUserScriptTests.swift
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

import WebKit
import XCTest
@testable import NewTabPage

final class NewTabPageUserScriptTests: XCTestCase {

    struct SampleEncodable: Equatable, Encodable {
        let value: String
    }

    func testThatHandlersAreCorrectlyRegistered() async throws {

        let script = NewTabPageUserScript()

        script.registerMessageHandlers([
            "foo": { (_, _) in return SampleEncodable(value: "foo") },
            "bar": { (_, _) in return SampleEncodable(value: "bar") },
            "baz": { (_, _) in return SampleEncodable(value: "baz") }
        ])

        let fooHandler = try XCTUnwrap(script.handler(forMethodNamed: "foo"))
        let barHandler = try XCTUnwrap(script.handler(forMethodNamed: "bar"))
        let bazHandler = try XCTUnwrap(script.handler(forMethodNamed: "baz"))

        let foo = try await fooHandler([], WKScriptMessage())
        let bar = try await barHandler([], WKScriptMessage())
        let baz = try await bazHandler([], WKScriptMessage())

        XCTAssertEqual(try XCTUnwrap(foo as? SampleEncodable), SampleEncodable(value: "foo"))
        XCTAssertEqual(try XCTUnwrap(bar as? SampleEncodable), SampleEncodable(value: "bar"))
        XCTAssertEqual(try XCTUnwrap(baz as? SampleEncodable), SampleEncodable(value: "baz"))
    }

    func testWhenHandlerWithTheSameNameIsRegisteredThenItOverridesPreviousHandler() async throws {

        let script = NewTabPageUserScript()

        script.registerMessageHandlers([
            "foo": { (_, _) in return SampleEncodable(value: "foo") }
        ])
        script.registerMessageHandlers([
            "foo": { (_, _) in return SampleEncodable(value: "bar") }
        ])

        let fooHandler = try XCTUnwrap(script.handler(forMethodNamed: "foo"))
        let foo = try await fooHandler([], WKScriptMessage())

        XCTAssertEqual(try XCTUnwrap(foo as? SampleEncodable), SampleEncodable(value: "bar"))
    }
}
