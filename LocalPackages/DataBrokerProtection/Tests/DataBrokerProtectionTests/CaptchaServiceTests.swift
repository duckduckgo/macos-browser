//
//  CaptchaServiceTests.swift
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

final class CaptchaServiceTests: XCTestCase {
    private let servicePixel = MockDataBrokerProtectionBackendServicePixels()
    let jsonEncoder = JSONEncoder()
    private let mockAuthenticationManager = MockAuthenticationManager()

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
        servicePixel.reset()
        mockAuthenticationManager.reset()
    }

    func testWhenSessionThrowsOnSubmittingCaptchaInfo_thenTheCorrectErrorIsThrown() async {
        MockURLProtocol.requestHandlerQueue.append({ _ in throw MockError.someError })
        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaInformation(GetCaptchaInfoResponse.mock, attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .errorWhenSubmittingCaptcha = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenFailureCriticalIsReturnedOnSubmittingCaptchaInfo_thenCriticalErrorWhenSubmittingCaptchaIsThrown() async {
        let response = CaptchaTransaction(message: .failureCritical, transactionId: nil)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(response)) })
        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaInformation(GetCaptchaInfoResponse.mock, attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .criticalFailureWhenSubmittingCaptcha = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenInvalidRequestIsReturnedOnSubmittingCaptchaInfo_thenInvalidRequestWhenSubmittingCaptchaIsThrown() async {
        let response = CaptchaTransaction(message: .invalidRequest, transactionId: nil)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(response)) })
        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaInformation(GetCaptchaInfoResponse.mock, attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .invalidRequestWhenSubmittingCaptcha = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenFailureTransientMaxesRetriesOnSubmittingCaptchaInfo_thenTimedOutErrorIsThrown() async {
        let captchaTransaction = CaptchaTransaction(message: .failureTransient, transactionId: nil)
        let requestHandler: RequestHandler = { _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(captchaTransaction)) }
        MockURLProtocol.requestHandlerQueue.append(requestHandler)
        MockURLProtocol.requestHandlerQueue.append(requestHandler)
        MockURLProtocol.requestHandlerQueue.append(requestHandler)

        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaInformation(GetCaptchaInfoResponse.mock, retries: 2, pollingInterval: 0.01, attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .timedOutWhenSubmittingCaptcha = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenFailureOnFetchingCaptchaResult_thenFailureErrorIsThrown() async {
        let captchaResult = CaptchaResult(data: nil, message: .failure, meta: Meta.mock)
        let requestHandler: RequestHandler = { _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(captchaResult)) }
        MockURLProtocol.requestHandlerQueue.append(requestHandler)

        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaToBeResolved(for: "123456", attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .failureWhenFetchingCaptchaResult = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenInvalidRequestOnFetchingCaptchaResult_thenInvalidRequestErrorIsThrown() async {
        let captchaResult = CaptchaResult(data: nil, message: .invalidRequest, meta: Meta.mock)
        let requestHandler: RequestHandler = { _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(captchaResult)) }
        MockURLProtocol.requestHandlerQueue.append(requestHandler)

        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaToBeResolved(for: "123456", attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .invalidRequestWhenFetchingCaptchaResult = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenCaptchaResultIsReadyButDataIsNil_thenNilDataErrorIsThrown() async {
        let captchaResult = CaptchaResult(data: nil, message: .ready, meta: Meta.mock)
        let requestHandler: RequestHandler = { _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(captchaResult)) }
        MockURLProtocol.requestHandlerQueue.append(requestHandler)

        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaToBeResolved(for: "123456", attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .nilDataWhenFetchingCaptchaResult = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenCaptchaResultIsNotReadyAndRetriesRunOut_thenTimedOutErrorIsThrown() async {
        let captchaResult = CaptchaResult(data: nil, message: .notReady, meta: Meta.mock)
        let requestHandler: RequestHandler = { _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(captchaResult)) }
        MockURLProtocol.requestHandlerQueue.append(requestHandler)
        MockURLProtocol.requestHandlerQueue.append(requestHandler)
        MockURLProtocol.requestHandlerQueue.append(requestHandler)

        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaToBeResolved(for: "123456", retries: 2, pollingInterval: 0.01, attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? CaptchaServiceError, case .timedOutWhenFetchingCaptchaResult = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenCaptchaResultIsReady_thenCaptchaResultDataIsReturned() async {
        let captchaResult = CaptchaResult(data: "some data", message: .ready, meta: Meta.mock)
        let requestHandler: RequestHandler = { _ in (HTTPURLResponse.ok, try? self.jsonEncoder.encode(captchaResult)) }
        MockURLProtocol.requestHandlerQueue.append(requestHandler)

        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            let data = try await sut.submitCaptchaToBeResolved(for: "123456", retries: 2, pollingInterval: 1, attemptId: UUID(), shouldRunNextStep: { true })
            XCTAssertEqual(data, "some data")
        } catch {
            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenNoAuthTokenAvailable_noAuthTokenErrorIsThrown() async {
        mockAuthenticationManager.authHeaderValue = nil

        let sut = CaptchaService(urlSession: mockURLSession,
                                 authenticationManager: mockAuthenticationManager,
                                 settings: DataBrokerProtectionSettings(defaults: .standard),
                                 servicePixel: servicePixel)

        do {
            _ = try await sut.submitCaptchaToBeResolved(for: "123456", retries: 2, pollingInterval: 1, attemptId: UUID(), shouldRunNextStep: { true })
            XCTFail("Expected an error to be thrown")
        } catch {
            guard let authenticationError = error as? AuthenticationError, authenticationError == .noAuthToken else {
                XCTFail("Error is not AuthenticationError.noAuthToken")
                return
            }
            XCTAssertTrue(servicePixel.fireEmptyAccessTokenWasCalled)
            XCTAssertFalse(servicePixel.fireGenerateEmailHTTPErrorWasCalled)
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

extension Meta {
    static var mock: Meta {
        Meta(lastBackend: "", backends: [String: Backend](), timeToSolution: 2.0, type: "type", lastUpdated: 1.0)
    }
}
