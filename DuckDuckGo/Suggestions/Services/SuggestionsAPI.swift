//
//  SuggestionsAPI.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log

protocol SuggestionsAPI {

    func fetchSuggestions(for query: String, completion: @escaping ([Suggestion]?, Error?) -> Void)

}

class DuckDuckGoSuggestionsAPI: SuggestionsAPI {

    enum FetchSuggestionsError: Error {
        case urlInitFailed
        case decodingFailed
        case dataTaskInitFailed
    }

    private var task: URLSessionDataTask?

    func fetchSuggestions(for query: String, completion: @escaping ([Suggestion]?, Error?) -> Void) {
        func mainQueueCompletion(_ suggestions: [Suggestion]?, _ error: Error?) {
            DispatchQueue.main.async {
                completion(suggestions, error)
            }
        }

        //todo resolve problems with cancel
//        task?.cancel()
        task = nil

        let url = URL.duckDuckGoAutocomplete
        guard let searchUrl = try? url.addParameter(name: URL.DuckDuckGoParameters.search.rawValue, value: query) else {
            os_log("DuckDuckGoSuggestionsAPI: Failed to add parameter", log: OSLog.Category.general, type: .error)
            mainQueueCompletion(nil, FetchSuggestionsError.urlInitFailed)
            return
        }

        let request = URLRequest(url: searchUrl)
        task = URLSession.shared.dataTask(with: request, completionHandler: { (data, _, error) in
            guard let data = data else {
                os_log("DuckDuckGoSuggestionsAPI: Failed to fetch suggestions - %s",
                       log: OSLog.Category.general,
                       type: .error, error?.localizedDescription ?? "")
                mainQueueCompletion(nil, error)
                return
            }

            let decoder = JSONDecoder()
            guard let suggestionsResult = try? decoder.decode(SuggestionsAPIResult.self, from: data) else {
                os_log("DuckDuckGoSuggestionsAPI: Failed to decode suggestions", log: OSLog.Category.general, type: .error)
                mainQueueCompletion(nil, FetchSuggestionsError.decodingFailed)
                return
            }

            mainQueueCompletion(suggestionsResult.suggestions, nil)
        })

        guard task != nil else {
            os_log("DuckDuckGoSuggestionsAPI: Failed to init data task", log: OSLog.Category.general, type: .error)
            mainQueueCompletion(nil, FetchSuggestionsError.dataTaskInitFailed)
            return
        }

        task?.resume()
    }

}
