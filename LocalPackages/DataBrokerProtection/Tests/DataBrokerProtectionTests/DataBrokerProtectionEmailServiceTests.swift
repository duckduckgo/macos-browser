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

extension HTTPURLResponse {
    static let ok = HTTPURLResponse(url: URL(string: "www.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [String : String]())!
}

final class DataBrokerProtectionEmailServiceTests: XCTestCase {

    enum MockError: Error {
        case someError
    }

    private var mockURLSession: URLSession {
        let testConfiguration = URLSessionConfiguration.default
        testConfiguration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: testConfiguration)
    }

    func testWhenSessionThrows_thenTheCorrectErrorIsThrown() async {
        MockURLProtocol.requestHandler = { _ in throw MockError.someError }
        let sut = DataBrokerProtectionEmailService(urlSession: mockURLSession)

        do {
            _ = try await sut.getEmail()
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? DataBrokerProtectionEmailService.EmailError,
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
        MockURLProtocol.requestHandler = { _ in (HTTPURLResponse.ok, responseData) }

        let sut = DataBrokerProtectionEmailService(urlSession: mockURLSession)

        do {
            _ = try await sut.getEmail()
            XCTFail("Expected an error to be thrown")
        } catch {
            if let error = error as? DataBrokerProtectionEmailService.EmailError, case .cantFindEmail = error {
                return
            }

            XCTFail("Unexpected error thrown: \(error).")
        }
    }

    func testWhenResponseIsCorrect_thenTheEmailIsReturned() async {
        let responseDictionary = ["emailAddress": "test@ddg.com"]
        let responseData = try? JSONSerialization.data(withJSONObject: responseDictionary, options: .prettyPrinted)
        MockURLProtocol.requestHandler = { _ in (HTTPURLResponse.ok, responseData) }

        let sut = DataBrokerProtectionEmailService(urlSession: mockURLSession)

        do {
            let email = try await sut.getEmail()
            XCTAssertEqual("test@ddg.com", email)
        } catch {
            XCTFail("Unexpected. It should not throw")
        }
    }
}

final class MockURLProtocol: URLProtocol {

    static var lastRequest: URLRequest?
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
        }
        MockURLProtocol.lastRequest = request

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }

}
