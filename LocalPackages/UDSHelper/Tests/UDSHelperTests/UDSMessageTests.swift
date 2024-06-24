//
//  UDSMessageTests.swift
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
@testable import UDSHelper

final class UDSMessageTests: XCTestCase {
    func testExample() throws {
        let uuid = UUID()
        let requestData = "request".data(using: .utf8)!
        let responseData = "response".data(using: .utf8)!

        let message = UDSMessage(uuid: uuid, body: .request(requestData))
        XCTAssertEqual(message.uuid, uuid)

        let response = message.successResponse(withPayload: responseData)
        XCTAssertEqual(response.uuid, uuid)

        switch response.body {
        case .request:
            XCTFail("Expected a response body")
        case .response(let result):
            switch result {
            case .success(let data):
                XCTAssertEqual(data, responseData)
            case .failure:
                XCTFail("Expected a success response")
            }
        }
    }
}
