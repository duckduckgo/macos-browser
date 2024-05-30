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
import Networking

protocol HomePageRemoteMessagingRequest {

    func fetchHomePageRemoteMessages() async -> Result<[SurveyRemoteMessage], Error>

}

final class DefaultHomePageRemoteMessagingRequest: HomePageRemoteMessagingRequest {

    enum SurveysEndpoint {
        case debug
        case production

        var url: URL {
            switch self {
            case .debug: return URL(string: "https://staticcdn.duckduckgo.com/macos-desktop-browser/surveys/surveys-debug.json")!
            case .production: return URL(string: "https://staticcdn.duckduckgo.com/macos-desktop-browser/surveys/surveys.json")!
            }
        }
    }

    enum HomePageRemoteMessagingRequestError: Error {
        case failedToDecodeMessages
        case requestCompletedWithoutErrorOrResponse
    }

    static func surveysRequest() -> HomePageRemoteMessagingRequest {
#if DEBUG || REVIEW
        return DefaultHomePageRemoteMessagingRequest(endpointURL: SurveysEndpoint.debug.url)
#else
        return DefaultHomePageRemoteMessagingRequest(endpointURL: SurveysEndpoint.production.url)
#endif
    }

    private let endpointURL: URL

    init(endpointURL: URL) {
        self.endpointURL = endpointURL
    }

    func fetchHomePageRemoteMessages() async -> Result<[SurveyRemoteMessage], Error> {
        let httpMethod = APIRequest.HTTPMethod.get
        let configuration = APIRequest.Configuration(url: endpointURL, method: httpMethod, body: nil)
        let request = APIRequest(configuration: configuration)

        do {
            let response = try await request.fetch()

            guard let data = response.data else {
                return .failure(HomePageRemoteMessagingRequestError.requestCompletedWithoutErrorOrResponse)
            }

            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([SurveyRemoteMessage].self, from: data)
                return .success(decoded)
            } catch {
                return .failure(HomePageRemoteMessagingRequestError.failedToDecodeMessages)
            }
        } catch {
            return .failure(error)
        }
    }

}
