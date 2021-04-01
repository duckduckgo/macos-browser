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

    func fetchSuggestions(for query: String, completion: @escaping (SuggestionsAPIResult?, Error?) -> Void)
    func stopFetchingSuggestions()

}

final class DuckDuckGoSuggestionsAPI: SuggestionsAPI {

    enum FetchSuggestionsError: Error {
        case urlInitFailed
        case decodingFailed
        case dataTaskInitFailed
    }

    private var task: URLSessionDataTask?

    func fetchSuggestions(for query: String, completion: @escaping (SuggestionsAPIResult?, Error?) -> Void) {

        func mainQueueCompletion(_ suggestions: SuggestionsAPIResult?, _ error: Error?) {
            DispatchQueue.main.async {
                guard self.task != nil else { return }
                completion(suggestions, error)
            }
        }

        task = nil

        let url = URL.duckDuckGoAutocomplete
        guard let searchUrl = try? url.addParameter(name: URL.DuckDuckGoParameters.search.rawValue, value: query) else {
            os_log("DuckDuckGoSuggestionsAPI: Failed to add parameter", type: .error)
            Pixel.fire(.debug(event: .suggestionsFetchFailed, error: NSError(domain: "FailedToAddQueryParam", code: -1, userInfo: nil)))
            mainQueueCompletion(nil, FetchSuggestionsError.urlInitFailed)
            return
        }

        let request = URLRequest.defaultRequest(with: searchUrl)
        let task = URLSession.shared.dataTask(with: request, completionHandler: { [weak self] (data, _, error) in
            guard self != nil else { return }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                mainQueueCompletion(SuggestionsAPIResult(), nil)
                return
            }

            guard let data = data else {
                os_log("DuckDuckGoSuggestionsAPI: Failed to fetch suggestions - %s",
                       type: .error, error?.localizedDescription ?? "")
                Pixel.fire(.debug(event: .suggestionsFetchFailed, error: error))
                mainQueueCompletion(nil, error)
                return
            }

            let decoder = JSONDecoder()
            do {
                let suggestionsResult = try decoder.decode(SuggestionsAPIResult.self, from: data)
                mainQueueCompletion(suggestionsResult, nil)
            } catch {
                os_log("DuckDuckGoSuggestionsAPI: Failed to decode suggestions", type: .error)
                Pixel.fire(.debug(event: .suggestionsFetchFailed, error: error))
                mainQueueCompletion(nil, FetchSuggestionsError.decodingFailed)
            }
            
        })

        self.task = task
        task.resume()
    }

    func stopFetchingSuggestions() {
        guard task?.state == URLSessionTask.State.running else { return }

        task?.cancel()
        task = nil
    }

}
