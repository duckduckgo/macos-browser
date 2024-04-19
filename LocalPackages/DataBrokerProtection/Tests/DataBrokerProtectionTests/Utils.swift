//
//  Utils.swift
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

import Foundation

func areDatesEqualIgnoringSeconds(date1: Date?, date2: Date?) -> Bool {
    if date1 == date2 {
        return true
    }
    guard let date1 = date1, let date2 = date2 else {
        return false
    }
    let calendar = Calendar.current
    let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]

    let date1Components = calendar.dateComponents(components, from: date1)
    let date2Components = calendar.dateComponents(components, from: date2)

    let normalizedDate1 = calendar.date(from: date1Components)
    let normalizedDate2 = calendar.date(from: date2Components)

    return normalizedDate1 == normalizedDate2
}

func areDatesEqualsOnDayMonthAndYear(date1: Date?, date2: Date?) -> Bool {
    if date1 == date2 {
        return true
    }
    guard let date1 = date1, let date2 = date2 else {
        return false
    }
    let calendar = Calendar.current
    let components: Set<Calendar.Component> = [.year, .month, .day]

    let date1Components = calendar.dateComponents(components, from: date1)
    let date2Components = calendar.dateComponents(components, from: date2)

    let normalizedDate1 = calendar.date(from: date1Components)
    let normalizedDate2 = calendar.date(from: date2Components)

    return normalizedDate1 == normalizedDate2
}

extension HTTPURLResponse {
    static let ok = HTTPURLResponse(url: URL(string: "http://www.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [String: String]())!
    static let noAuth = HTTPURLResponse(url: URL(string: "http://www.example.com")!, statusCode: 401, httpVersion: nil, headerFields: [String: String]())!
}

typealias RequestHandler = ((URLRequest) throws -> (HTTPURLResponse, Data?))
final class MockURLProtocol: URLProtocol {

    static var lastRequest: URLRequest?
    static var requestHandlerQueue = [RequestHandler]()

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if MockURLProtocol.requestHandlerQueue.isEmpty {
            fatalError("Handler is unavailable.")
        }

        let handler = MockURLProtocol.requestHandlerQueue.removeFirst()
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
