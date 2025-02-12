//
//  MessageHelper.swift
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

import HistoryView
import XCTest

final class MessageHelper<MessageName: RawRepresentable> where MessageName.RawValue == String {
    let userScript: HistoryViewUserScript

    init(userScript: HistoryViewUserScript) {
        self.userScript = userScript
    }

    func handleMessage<Response: Encodable>(named methodName: MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(Self.asJSON(parameters), .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func handleMessageIgnoringResponse(named methodName: MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        _ = try await handler(Self.asJSON(parameters), .init())
    }

    func handleMessageExpectingNilResponse(named methodName: MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(Self.asJSON(parameters), .init())
        XCTAssertNil(response, file: file, line: line)
    }

    private static func asJSON(_ value: Any, file: StaticString = #file, line: UInt = #line) throws -> Any {
        if JSONSerialization.isValidJSONObject(value) {
            return value
        }
        if let encodableValue = value as? Encodable {
            let jsonData = try JSONEncoder().encode(encodableValue)
            return try JSONSerialization.jsonObject(with: jsonData)
        }
        XCTFail("invalid JSON value", file: file, line: line)
        return []
    }
}
