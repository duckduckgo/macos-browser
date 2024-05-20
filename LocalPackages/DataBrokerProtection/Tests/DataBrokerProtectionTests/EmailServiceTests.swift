//
//  EmailServiceTests.swift
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

final class EmailServiceTests: XCTestCase {
    private let servicePixel = MockDataBrokerProtectionBackendServicePixels()
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

    func testWhenSessionThrows_thenTheCorrectErrorIsThrown() async {
        MockURLProtocol.requestHandlerQueue.append({ _ in throw MockError.someError })
        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            _ = try await sut.getEmail(dataBrokerURL: "fakeBroker", attemptId: UUID())
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? EmailError,
                    case .cantFindEmail = error,
                    case .cantGenerateURL = error {
                XCTFail("Unexpected error thrown: \(error).")
            }

            return
        }
    }

    func testWhenResponseIsIncorrect_thenTheCantFindEmailExceptionIsThrown() async {
        let responseDictionary = [String: AnyObject]()
        let responseData = try? JSONSerialization.data(withJSONObject: responseDictionary, options: .prettyPrinted)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, responseData) })

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            _ = try await sut.getEmail(dataBrokerURL: "fakeBroker", attemptId: UUID())
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? EmailError, case .cantFindEmail = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenResponseIsCorrect_thenTheEmailIsReturned() async {
        let responseDictionary = ["emailAddress": "test@ddg.com"]
        let responseData = try? JSONSerialization.data(withJSONObject: responseDictionary, options: .prettyPrinted)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, responseData) })

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            let emailData = try await sut.getEmail(dataBrokerURL: "fakeBroker", attemptId: UUID())
            XCTAssertEqual("test@ddg.com", emailData.emailAddress)
        } catch {
            XCTFail("Unexpected. It should not throw")
        }
    }

    func testWhenEmailExtractingIsUnknown_thenUnknownErrorIsThrown() async {
        let responseDictionary = ["status": "unknown"]
        let responseData = try? JSONSerialization.data(withJSONObject: responseDictionary, options: .prettyPrinted)
        let unknownResponse: RequestHandler = { _ in (HTTPURLResponse.ok, responseData) }
        MockURLProtocol.requestHandlerQueue.append(unknownResponse)

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            _ = try await sut.getConfirmationLink(
                from: "some@email.com",
                numberOfRetries: 20,
                pollingInterval: 0.01,
                attemptId: UUID(),
                shouldRunNextStep: { true }
            )
        } catch {
            if let error = error as? EmailError, case .unknownStatusReceived = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenEmailExtractingExceedesRetries_thenTimeOutErrorIsThrown() async {
        let responseDictionary = ["status": "pending"]
        let responseData = try? JSONSerialization.data(withJSONObject: responseDictionary, options: .prettyPrinted)
        let notReadyResponse: RequestHandler = { _ in (HTTPURLResponse.ok, responseData) }
        MockURLProtocol.requestHandlerQueue.append(notReadyResponse)
        MockURLProtocol.requestHandlerQueue.append(notReadyResponse)
        MockURLProtocol.requestHandlerQueue.append(notReadyResponse)

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            _ = try await sut.getConfirmationLink(
                from: "some@email.com",
                numberOfRetries: 2,
                pollingInterval: 0.01,
                attemptId: UUID(),
                shouldRunNextStep: { true }
            )
        } catch {
            if let error = error as? EmailError, case .linkExtractionTimedOut = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenEmailSuccedesInLastRetry_thenSuccessIsReturned() async {
        let validURL = EmailResponse(status: .ready, link: "www.duckduckgo.com")
        let successResponseData = try? JSONEncoder().encode(validURL)
        let responseDictionary = ["status": "pending"]
        let responseData = try? JSONSerialization.data(withJSONObject: responseDictionary, options: .prettyPrinted)
        let notReadyResponse: RequestHandler = { _ in (HTTPURLResponse.ok, responseData) }
        let successResponse: RequestHandler = { _ in (HTTPURLResponse.ok, successResponseData) }
        MockURLProtocol.requestHandlerQueue.append(notReadyResponse)
        MockURLProtocol.requestHandlerQueue.append(notReadyResponse)
        MockURLProtocol.requestHandlerQueue.append(successResponse)

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            let url = try await sut.getConfirmationLink(
                from: "some@email.com",
                numberOfRetries: 2,
                pollingInterval: 0.01,
                attemptId: UUID(),
                shouldRunNextStep: { true }
            )
            XCTAssertEqual(url.absoluteString, "www.duckduckgo.com")
        } catch {
            XCTFail("Unexpected. It should not throw")
        }
    }

    func testWhenEmailCannotBeDecoded_thenCantFindEmailErrorIsThrown() async {
        let responseDictionary = ["link": ["test": "test"]]
        let responseData = try? JSONSerialization.data(withJSONObject: responseDictionary, options: .prettyPrinted)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, responseData) })

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            _ = try await sut.getConfirmationLink(
                from: "some@email.com",
                numberOfRetries: 20,
                pollingInterval: 0.01,
                attemptId: UUID(),
                shouldRunNextStep: { true }
            )
        } catch {
            if let error = error as? EmailError, case .cantFindEmail = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenEmailLinkIsInvalid_thenInvalidEmailLinkErrorIsThrown() async {
        let invalidLink = EmailResponse(status: .ready, link: "invalidURL")
        let responseData = try? JSONEncoder().encode(invalidLink)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, responseData) })

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            _ = try await sut.getConfirmationLink(
                from: "some@email.com",
                numberOfRetries: 1,
                pollingInterval: 0.01,
                attemptId: UUID(),
                shouldRunNextStep: { true }
            )
        } catch {
            if let error = error as? EmailError, case .invalidEmailLink = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenEmailLinkIsValid_thenTheURLIsReturned() async {
        let validURL = EmailResponse(status: .ready, link: "www.duckduckgo.com")
        let responseData = try? JSONEncoder().encode(validURL)
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.ok, responseData) })

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            let url = try await sut.getConfirmationLink(
                from: "some@email.com",
                numberOfRetries: 1,
                pollingInterval: 0.01,
                attemptId: UUID(),
                shouldRunNextStep: { true }
            )
            XCTAssertEqual(url.absoluteString, "www.duckduckgo.com")
        } catch {
            XCTFail("Unexpected. It should not throw")
        }
    }

    func testWhenNoAuthTokenAvailable_noAuthTokenErrorIsThrown() async {
        mockAuthenticationManager.authHeaderValue = nil
        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            _ = try await sut.getEmail(dataBrokerURL: "fakeBroker", attemptId: UUID())
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

    func testWhen401IsReceived_thenWeSubmit401ErrorPixel() async {
        MockURLProtocol.requestHandlerQueue.append({ _ in (HTTPURLResponse.noAuth, nil) })

        let sut = EmailService(urlSession: mockURLSession,
                               authenticationManager: mockAuthenticationManager,
                               settings: DataBrokerProtectionSettings(defaults: .standard),
                               servicePixel: servicePixel)

        do {
            _ = try await sut.getEmail(dataBrokerURL: "fakeBroker", attemptId: UUID())
            XCTFail("Expected an error to be thrown")
        } catch {
            XCTAssertFalse(servicePixel.fireEmptyAccessTokenWasCalled)
            XCTAssertTrue(servicePixel.fireGenerateEmailHTTPErrorWasCalled)
            XCTAssertEqual(servicePixel.statusCode, 401)
        }
    }
}
