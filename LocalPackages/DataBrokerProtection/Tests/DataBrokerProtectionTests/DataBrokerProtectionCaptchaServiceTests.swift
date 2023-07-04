//
//  DataBrokerProtectionEmailServiceTests.swift
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

final class DataBrokerProtectionCaptchaServiceTests: XCTestCase {
    let jsonEncoder = JSONEncoder()

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

    func testWhenSessionThrows_thenTheCorrectErrorIsThrown() async {
        MockURLProtocol.requestHandlerQueue.append({ _ in throw MockError.someError })
        let sut = DataBrokerProtectionCaptchaService(urlSession: mockURLSession)

        do {
            _ = try await sut.submitCaptchaInformation(GetCaptchaInfoResponse.mock)
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .errorWhenSubmittingCaptcha = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenFailureCriticalIsReturned_thenCriticalErrorWhenSubmittingCaptchaIsThrown() async {
        let response = CaptchaTransaction(message: .failureCritical, transactionId: nil)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(response)) })
        let sut = DataBrokerProtectionCaptchaService(urlSession: mockURLSession)

        do {
            _ = try await sut.submitCaptchaInformation(GetCaptchaInfoResponse.mock)
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .criticalFailureWhenSubmittingCaptcha = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenInvalidRequestIsReturned_thenInvalidRequestWhenSubmittingCaptchaIsThrown() async {
        let response = CaptchaTransaction(message: .invalidRequest, transactionId: nil)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(response)) })
        let sut = DataBrokerProtectionCaptchaService(urlSession: mockURLSession)

        do {
            _ = try await sut.submitCaptchaInformation(GetCaptchaInfoResponse.mock)
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .invalidRequestWhenSubmittingCaptcha = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenFailureTransientMaxesRetries_thenTimedOutErrorIsThrown() async {
        let captchaTransaction = CaptchaTransaction(message: .failureTransient, transactionId: nil)
        let requestHandler: RequestHandler = { _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(captchaTransaction)) }
        MockURLProtocol.requestHandlerQueue.append(requestHandler)
        MockURLProtocol.requestHandlerQueue.append(requestHandler)
        MockURLProtocol.requestHandlerQueue.append(requestHandler)

        let sut = DataBrokerProtectionCaptchaService(urlSession: mockURLSession)

        do {
            _ = try await sut.submitCaptchaInformation(GetCaptchaInfoResponse.mock, retries: 2)
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .timedOutWhenSubmittingCaptcha = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }
}

extension GetCaptchaInfoResponse {
    static var mock: GetCaptchaInfoResponse {
        GetCaptchaInfoResponse(
            siteKey: "siteKey",
            url: "www.duckduckgo.com",
            type: "recaptcha"
        )
    }
}
