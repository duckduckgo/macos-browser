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
    case noResponse
    case noEtagInResponse
    case etagMismatch
    case cachedDataMissing
    case unexpectedStatusCode(statusCode: Int)
    case noDataOnSuccess
    case savingData
    case savingEtag

}

// If you change any of these, add a migration to move or delete the old data
enum ConfigurationLocation: String {

    case bloomFilterSpec = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json"
    case bloomFilterBinary = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin"
    case bloomFilterExcludedDomains = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json"
    case surrogates = "https://duckduckgo.com/contentblocking.js?l=surrogates"
    case temporaryUnprotectedSites = "https://duckduckgo.com/contentblocking/trackers-whitelist-temporary.txt"
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

    init(storage: ConfigurationStoring = DefaultConfigurationStorage()) {
        self.storage = storage
    }

    /// Returns new data from the given data and response object, nil if there's nothing new, or throws an error if something is wrong
    private func newDataFrom(_ value: (data: Data, response: URLResponse), currentEtag: String?, cachedData: Data?)
            throws -> (etag: String, data: Data)? {

        guard let response = value.response as? HTTPURLResponse else {
            throw ConfigurationDownloadError.noResponse
        }

        guard let etag = response.value(forHTTPHeaderField: Constants.etagField) else {
            throw ConfigurationDownloadError.noEtagInResponse
        }

        switch response.statusCode {
        case Constants.notModifiedResponseCode:

            guard etag == currentEtag else {
                throw ConfigurationDownloadError.etagMismatch
            }

            if cachedData == nil {
                throw ConfigurationDownloadError.cachedDataMissing
            }

            return nil

        case Constants.successResponseCode:

            guard !value.data.isEmpty else {
                throw ConfigurationDownloadError.noDataOnSuccess
            }

            return (etag: etag, data: value.data)

        default:
            throw ConfigurationDownloadError.unexpectedStatusCode(statusCode: response.statusCode)

        }

    }

    func download(_ config: ConfigurationLocation, embeddedEtag: String?) -> AnyPublisher<(etag: String, data: Data)?, Error> {

        let url = URL(string: config.rawValue)!
        let currentEtag = storage.loadEtag(for: config) ?? embeddedEtag

        return Future { promise in
            var request = URLRequest(url: url)
            request.addValue(Constants.userAgent, forHTTPHeaderField: Constants.userAgentField)

            let cachedData = self.storage.loadData(for: config)
            if let etag = currentEtag, cachedData != nil {
                request.addValue(etag, forHTTPHeaderField: Constants.ifNoneMatchField)
            }

            URLSession.shared.dataTaskPublisher(for: request).sink { completion in

                if case .failure(let error) = completion {
                    promise(.failure(ConfigurationDownloadError.urlSessionError(error: error)))
                }

            } receiveValue: { value in

                do {
                    if let meta = try self.newDataFrom(value, currentEtag: currentEtag, cachedData: cachedData) {
                        try self.storage.saveData(meta.data, for: config)
                        try self.storage.saveEtag(meta.etag, for: config)
                        promise(.success(meta))
                    } else {
                        promise(.success(nil))
                    }

                } catch {
                    promise(.failure(error))
                }

            }.store(in: &self.cancellables)

        }.eraseToAnyPublisher()
    }

    func cancelAll() {

        let cancellables = self.cancellables
        self.cancellables.removeAll()
        cancellables.forEach { $0.cancel() }

    }

}
