//
//  NetworkProtectionRemoteMessagingRequest.swift
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
import Networking

protocol NetworkProtectionRemoteMessagingRequest {

    func fetchNetworkProtectionRemoteMessages(completion: @escaping (Result<[NetworkProtectionRemoteMessage], Error>) -> Void)

}

final class DefaultNetworkProtectionRemoteMessagingRequest: NetworkProtectionRemoteMessagingRequest {

    enum Endpoint {
        case debug
        case production

        var url: URL {
            switch self {
            case .debug: return URL(string: "https://staticcdn.duckduckgo.com/macos-desktop-browser/network-protection/messages-v2-debug.json")!
            case .production: return URL(string: "https://staticcdn.duckduckgo.com/macos-desktop-browser/network-protection/messages-v2.json")!
            }
        }
    }

    enum NetworkProtectionRemoteMessagingRequestError: Error {
        case failedToDecodeMessages
        case requestCompletedWithoutErrorOrResponse
    }

    private let endpointURL: URL

    init() {
#if DEBUG || REVIEW
        endpointURL = Endpoint.debug.url
#else
        endpointURL = Endpoint.production.url
#endif
    }

    func fetchNetworkProtectionRemoteMessages(completion: @escaping (Result<[NetworkProtectionRemoteMessage], Error>) -> Void) {
        let httpMethod = APIRequest.HTTPMethod.get
        let configuration = APIRequest.Configuration(url: endpointURL, method: httpMethod, body: nil)
        let request = APIRequest(configuration: configuration)

        request.fetch { response, error in
            if let error {
                completion(Result.failure(error))
            } else if let responseData = response?.data {
                do {
                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode([NetworkProtectionRemoteMessage].self, from: responseData)
                    completion(Result.success(decoded))
                } catch {
                    completion(.failure(NetworkProtectionRemoteMessagingRequestError.failedToDecodeMessages))
                }
            } else {
                completion(.failure(NetworkProtectionRemoteMessagingRequestError.requestCompletedWithoutErrorOrResponse))
            }
        }
    }

}
