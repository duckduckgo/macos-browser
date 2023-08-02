//
//  AuthenticationServiceTests.swift
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

import XCTest
import Foundation
@testable import DataBrokerProtection

final class AuthenticationServiceTests: XCTestCase {

    enum MockError: Error {
        case someError
    }

    private var mockURLSession: URLSession {
        let testConfiguration = URLSessionConfiguration.default
        testConfiguration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: testConfiguration)
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandlerQueue.removeAll()
    }

    func testWhenFailsOnNetworkingLayer_thenNoAuthenticationErrorIsThrown() async {
        MockURLProtocol.requestHandlerQueue.append({ _ in throw MockError.someError })
        let sut = AuthenticationService(urlSession: mockURLSession)

        do {
            _ = try await sut.redeem(inviteCode: "someInviteCode")
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? AuthenticationError {
                XCTFail("Unexpected error thrown: \(error).")
            }
        }
    }

    func testWhenFailsToRedeemWithNoAccessTokenAndMessage_thenUnknownErrorIsThrown() async {
        let emptyMessageResponseData = try? JSONEncoder().encode(RedeemResponse(accessToken: nil, message: nil))
        let emptyMessageResponse: RequestHandler = { _ in (HTTPURLResponse.ok, emptyMessageResponseData) }
        MockURLProtocol.requestHandlerQueue.append(emptyMessageResponse)
        let sut = AuthenticationService(urlSession: mockURLSession)

        do {
            _ = try await sut.redeem(inviteCode: "someInviteCode")
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? AuthenticationError, case .issueRedeemingInviteCode(let error) = error {
                if error != "Unknown" {
                    XCTFail("Unexpected error thrown: \(error).")
                }

                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenFailsToRedeemWithMessage_thenIssueRedeemingInviteCodeIsThrown() async {
        let message = "FAILURE CRITICAL: Error"
        let failureCriticalResponseData = try? JSONEncoder().encode(RedeemResponse(accessToken: nil, message: message))
        let failureCriticalResponse: RequestHandler = { _ in (HTTPURLResponse.ok, failureCriticalResponseData) }
        MockURLProtocol.requestHandlerQueue.append(failureCriticalResponse)
        let sut = AuthenticationService(urlSession: mockURLSession)

        do {
            _ = try await sut.redeem(inviteCode: "someInviteCode")
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? AuthenticationError, case .issueRedeemingInviteCode(let error) = error {
                if error != message {
                    XCTFail("Unexpected error thrown: \(error).")
                }

                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenAccessTokenIsRetrieved_thenAccessTokenIsReturned() async {
        let emptyMessageResponseData = try? JSONEncoder().encode(RedeemResponse(accessToken: "accessToken", message: nil))
        let emptyMessageResponse: RequestHandler = { _ in (HTTPURLResponse.ok, emptyMessageResponseData) }
        MockURLProtocol.requestHandlerQueue.append(emptyMessageResponse)
        let sut = AuthenticationService(urlSession: mockURLSession)

        do {
            let accessToken = try await sut.redeem(inviteCode: "someInviteCode")
            XCTAssertEqual(accessToken, "accessToken")
        } catch {
            XCTFail("Unexpected error thrown: \(error).")
        }
    }
}
