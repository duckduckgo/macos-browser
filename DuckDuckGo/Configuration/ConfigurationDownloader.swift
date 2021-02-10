//
//  ConfigurationDownloader.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Combine

protocol ConfigurationDownloader {

    func download(_ config: ConfigurationLocation, embeddedEtag: String?) -> AnyPublisher<(etag: String, data: Data)?, Error>
    func cancelAll()

}

struct ConfigurationDownloadMeta {

    var etag: String
    var data: Data

}

enum ConfigurationDownloadError: Error {

    case urlSessionError(error: Error)
    case noEtagInResponse
    case invalidResponse
    case savingData
    case savingEtag

}

enum ConfigurationLocation: String {

    case bloomFilterSpec = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json"
    case bloomFilterBinary = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin"
    case bloomFilterExcludedDomains = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json"
    case surrogates = "https://duckduckgo.com/contentblocking.js?l=surrogates"
    case temporaryUnprotectedSites = "https://duckduckgo.com/contentblocking/trackers-unprotected-temporary.txt"
    case trackerRadar = "https://staticcdn.duckduckgo.com/trackerblocking/v2.1/tds.json"

}

class DefaultConfigurationDownloader: ConfigurationDownloader {

    struct Constants {
        static let userAgent = "macos_ddg_dev"
        static let userAgentField = "User-Agent"
        static let ifNoneMatchField = "If-None-Match"
        static let etagField = "Etag"
        static let notModifiedResponseCode = 304
        static let successResponseCode = 200
    }

    let storage: ConfigurationStoring

    private var cancellables = Set<AnyCancellable>()

    init(storage: ConfigurationStoring = DefaultConfigurationStorage.shared) {
        self.storage = storage
    }

    func download(_ config: ConfigurationLocation, embeddedEtag: String?) -> AnyPublisher<(etag: String, data: Data)?, Error> {

        let url = URL(string: config.rawValue)!

        return Future { promise in
            var request = URLRequest(url: url)
            request.addValue(Constants.userAgent, forHTTPHeaderField: Constants.userAgentField)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            if self.storage.loadData(for: config) != nil,
               let etag = self.storage.loadEtag(for: config) ?? embeddedEtag {

                print("*** sending etag", etag, "for", config.rawValue)
                request.addValue(etag, forHTTPHeaderField: Constants.ifNoneMatchField)
            }

            // Uses protocol based caching.
            //  Our server disables absolute caching but returns an etag which URL session always checks against
            URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { result -> (etag: String, data: Data)? in
                    guard let response = result.response as? HTTPURLResponse else {
                        throw ConfigurationDownloadError.invalidResponse
                    }

                    print("***", config.rawValue, response.statusCode)
                    if response.statusCode == Constants.notModifiedResponseCode {
                        print("***", config.rawValue, "[NOT MODIFIED]")
                        return nil
                    }

                    guard let etag = response.value(forHTTPHeaderField: Constants.etagField) else {
                        throw ConfigurationDownloadError.noEtagInResponse
                    }

                    try self.storage.saveData(result.data, for: config)
                    try self.storage.saveEtag(etag, for: config)

                    return (etag: etag, data: result.data)
                }
                .print()
                .sink(receiveCompletion: { completion in

                    print("download", config, "completion received", completion)

                    if case .failure(let error) = completion {
                        promise(.failure(error))
                    }

                }) { value in

                    print("download", config, "value received", value == nil ? "value is nil" : "new data!")
                    promise(.success((value)))

                }.store(in: &self.cancellables)

        }.eraseToAnyPublisher()

    }

    func cancelAll() {

        let cancellables = self.cancellables
        self.cancellables.removeAll()
        cancellables.forEach { $0.cancel() }

    }

}
