//
//  HomePageRemoteMessagingRequest.swift
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
import Macros
import Networking

protocol HomePageRemoteMessagingRequest {

    func fetchHomePageRemoteMessages<T: Decodable>(completion: @escaping (Result<[T], Error>) -> Void)

}

final class DefaultHomePageRemoteMessagingRequest: HomePageRemoteMessagingRequest {

    enum NetworkProtectionEndpoint {
        case debug
        case production

        var url: URL {
            switch self {
            case .debug: return #URL("https://staticcdn.duckduckgo.com/macos-desktop-browser/network-protection/messages-v2-debug.json")
            case .production: return #URL("https://staticcdn.duckduckgo.com/macos-desktop-browser/network-protection/messages-v2.json")
            }
        }
    }

    enum DataBrokerProtectionEndpoint {
        case debug
        case production

        var url: URL {
            switch self {
            case .debug: return #URL("https://staticcdn.duckduckgo.com/macos-desktop-browser/dbp/messages-debug.json")
            case .production: return #URL("https://staticcdn.duckduckgo.com/macos-desktop-browser/dbp/messages.json")
            }
        }
    }

    enum HomePageRemoteMessagingRequestError: Error {
        case failedToDecodeMessages
        case requestCompletedWithoutErrorOrResponse
    }

    static func networkProtectionMessagesRequest() -> HomePageRemoteMessagingRequest {
#if DEBUG || REVIEW
        return DefaultHomePageRemoteMessagingRequest(endpointURL: NetworkProtectionEndpoint.debug.url)
#else
        return DefaultHomePageRemoteMessagingRequest(endpointURL: NetworkProtectionEndpoint.production.url)
#endif
    }

    static func dataBrokerProtectionMessagesRequest() -> HomePageRemoteMessagingRequest {
#if DEBUG || REVIEW
        return DefaultHomePageRemoteMessagingRequest(endpointURL: DataBrokerProtectionEndpoint.debug.url)
#else
        return DefaultHomePageRemoteMessagingRequest(endpointURL: DataBrokerProtectionEndpoint.production.url)
#endif
    }

    private let endpointURL: URL

    init(endpointURL: URL) {
        self.endpointURL = endpointURL
    }

    func fetchHomePageRemoteMessages<T: Decodable>(completion: @escaping (Result<[T], Error>) -> Void) {
        let httpMethod = APIRequest.HTTPMethod.get
        let configuration = APIRequest.Configuration(url: endpointURL, method: httpMethod, body: nil)
        let request = APIRequest(configuration: configuration)

        request.fetch { response, error in
            if let error {
                completion(Result.failure(error))
            } else if let responseData = response?.data {
                do {
                    let decoder = JSONDecoder()
                    let decoded = try decoder.decode([T].self, from: responseData)
                    completion(Result.success(decoded))
                } catch {
                    completion(.failure(HomePageRemoteMessagingRequestError.failedToDecodeMessages))
                }
            } else {
                completion(.failure(HomePageRemoteMessagingRequestError.requestCompletedWithoutErrorOrResponse))
            }
        }
    }

}
