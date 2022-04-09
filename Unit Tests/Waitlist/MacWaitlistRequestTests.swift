//
//  MacWaitlistRequestTests.swift
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

import OHHTTPStubs
import OHHTTPStubsSwift
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class MacWaitlistRequestTests: XCTestCase {

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }

    func testWhenMakingSuccessfulRequest_ThenRedeemedResponseIsReturned() {
        let expect = expectation(description: #function)
        let request = MacWaitlistAPIRequest()

        stub(condition: isHost(URL.redeemMacWaitlistInviteCode().host!)) { _ in
            let jsonData = """
                {
                    "status": "redeemed"
                }
                """.data(using: .utf8)!
            return HTTPStubsResponse(data: jsonData, statusCode: 200, headers: nil)
        }

        request.unlock(with: "code") { result in
            if case .success(let response) = result {
                XCTAssertTrue(response.hasExpectedStatusMessage)
                XCTAssertEqual(response.status, "redeemed")
            } else {
                XCTFail("Failed to get the expected response")
            }

            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenRedeemingExistingCode_ThenErrorResponseIsReturned() {
        let expect = expectation(description: #function)
        let request = MacWaitlistAPIRequest()

        stub(condition: isHost(URL.redeemMacWaitlistInviteCode().host!)) { _ in
            let jsonData = """
                {
                    "error": "already_redeemed_invite_code"
                }
                """.data(using: .utf8)!
            return HTTPStubsResponse(data: jsonData, statusCode: 400, headers: nil)
        }

        request.unlock(with: "code") { result in
            if case .failure(let error) = result {
                XCTAssertEqual(error, .redemptionError)
            } else {
                XCTFail("Failed to get the expected response")
            }

            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

}
