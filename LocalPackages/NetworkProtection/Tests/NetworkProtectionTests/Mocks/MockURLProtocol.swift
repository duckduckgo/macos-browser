//
//  MockURLProtocol.swift
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

final class MockURLProtocol: URLProtocol {
    static var stubs: [URL: (response: URLResponse, result: Result<Data, Error>)] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return stubs.keys.contains(url)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // Subclassing required
        return request
    }

    override func startLoading() {
        guard let stub = MockURLProtocol.stubs[self.request.url!] else {
            fatalError(
                "No mock response for \(request.url!). This should never happen. Check " +
                "the implementation of `canInit(with request: URLRequest) -> Bool`"
            )
        }

        self.client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .allowed)

        switch stub.result {
        case let .success(data):

            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)

        case let .failure(error):

            self.client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Subclassing required
    }
}
