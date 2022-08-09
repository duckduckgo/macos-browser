//
//  ConfigurationDownloading.swift
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

import Foundation
import Combine
import BrowserServicesKit

protocol ConfigurationDownloading {

    func refreshDataThenUpdate(for locations: [ConfigurationLocation], _ updater: @escaping () throws -> Void)
            -> AnyPublisher<[ConfigurationDownloadMeta?], Swift.Error>
    func cancelAll()

}

struct ConfigurationDownloadMeta {

    var etag: String
    var data: Data

}

enum ConfigurationLocation: String, CaseIterable {

    case bloomFilterSpec = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json"
    case bloomFilterBinary = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin"
    case bloomFilterExcludedDomains = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json"
    case surrogates = "https://duckduckgo.com/contentblocking.js?l=surrogates"
    case trackerRadar = "https://staticcdn.duckduckgo.com/trackerblocking/v2.1/apple-tds.json"
    case privacyConfiguration = "http://localhost:8080/generated/v2/macos-config.json"
    // In archived repo, to be refactored shortly (https://staticcdn.duckduckgo.com/useragents/social_ctp_configuration.json)
    case FBConfig = "https://staticcdn.duckduckgo.com/useragents/"
    
}

final class DefaultConfigurationDownloader: ConfigurationDownloading {

    enum Error: Swift.Error {

        case urlSessionError(error: Swift.Error)
        case noEtagInResponse
        case invalidResponse
        case savingData
        case savingEtag

    }

    struct Constants {
        static let ifNoneMatchField = "If-None-Match"
        static let etagField = "Etag"
        static let notModifiedResponseCode = 304
        static let successResponseCode = 200
    }

    let storage: ConfigurationStoring
    let dataTaskProvider: DataTaskProviding

    private var cancellables = Set<AnyCancellable>()
    private let deliveryQueue: DispatchQueue

    init(storage: ConfigurationStoring = DefaultConfigurationStorage.shared,
         dataTaskProvider: DataTaskProviding = SharedURLSessionDataTaskProvider(),
         deliveryQueue: DispatchQueue) {
        self.storage = storage
        self.dataTaskProvider = dataTaskProvider
        self.deliveryQueue = deliveryQueue
    }

    func download(_ config: ConfigurationLocation, embeddedEtag: String?) -> AnyPublisher<ConfigurationDownloadMeta?, Swift.Error> {

        let url = URL(string: config.rawValue)!

        return Future { promise in
            var request = URLRequest.defaultRequest(with: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let storedEtag = self.storage.loadEtag(for: config)

            if let embeddedEtag = embeddedEtag, storedEtag == nil {
                request.addValue(embeddedEtag, forHTTPHeaderField: Constants.ifNoneMatchField)
            } else if self.storage.loadData(for: config) != nil, let etag = storedEtag {
                request.addValue(etag, forHTTPHeaderField: Constants.ifNoneMatchField)
            }

            self.dataTaskProvider.dataTaskPublisher(for: request)
                .tryMap { result -> ConfigurationDownloadMeta? in
                    guard let response = result.response as? HTTPURLResponse else {
                        throw Error.invalidResponse
                    }

                    if response.statusCode == Constants.notModifiedResponseCode {
                        return nil
                    }

                    guard let etag = response.value(forHTTPHeaderField: Constants.etagField) else {
                        throw Error.noEtagInResponse
                    }

                    try self.storage.saveData(result.data, for: config)
                    try self.storage.saveEtag(etag, for: config)

                    return ConfigurationDownloadMeta(etag: etag, data: result.data)
                }
                .sink(receiveCompletion: { completion in

                    if case .failure(let error) = completion {
                        promise(.failure(error))
                    }

                }) { value in
                    
                    promise(.success((value)))

                }.store(in: &self.cancellables)

        }.eraseToAnyPublisher()

    }

    func cancelAll() {

        let cancellables = self.cancellables
        self.cancellables.removeAll()
        cancellables.forEach { $0.cancel() }

    }

    func embeddedEtag(for config: ConfigurationLocation) -> String? {
        switch config {
        case .trackerRadar: return AppTrackerDataSetProvider.Constants.embeddedDataETag
        case .privacyConfiguration: return AppPrivacyConfigurationDataProvider.Constants.embeddedDataSHA
        default: return nil
        }
    }

    func refreshDataThenUpdate(for locations: [ConfigurationLocation], _ updater: @escaping () throws -> Void)
            -> AnyPublisher<[ConfigurationDownloadMeta?], Swift.Error> {

        Publishers.MergeMany(
            locations.map {
                download($0, embeddedEtag: embeddedEtag(for: $0))
            }
        )
        .receive(on: self.deliveryQueue)
        .collect()
        .tryMap { result -> [ConfigurationDownloadMeta?] in
            if !result.compactMap({$0}).isEmpty {
                try updater()
            }
            return result
        }.eraseToAnyPublisher()

    }

}
