//
//  ConfigurationManager.swift
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
import os

class ConfigurationManager {

    enum Error: Swift.Error {
        case timeout
    }

    struct Constants {
        static let downloadTimeoutSeconds = 10.0
        static let refreshPeriodSeconds = 60.0 * 60 * 12
        static let retryDelaySeconds = 60.0 * 60
    }

    static let shared = ConfigurationManager()

    let queue: DispatchQueue = DispatchQueue(label: "Configuration Manager")

    @UserDefaultsWrapper(key: .configurationLastUpdated, defaultValue: Date())
    var lastUpdateTime: Date

    var cancellable: AnyCancellable?

    private init() { }

    func checkForDownloads() {
        // Quickly exit if it's not time
        guard self.isReadyToUpdate() else { return }

        queue.async {
            print(#function)

            // Check again, in case a previous operation completed since this one started
            guard self.isReadyToUpdate() else { return }

            let configDownloader: ConfigurationDownloader = DefaultConfigurationDownloader()

            var cancellable: AnyCancellable?
            cancellable =
                TrackerRadarConfigurationUpdater(downloader: configDownloader).update()
                .merge(with: TemporaryUnprotectedSitesConfigurationUpdater(downloader: configDownloader).update())
                .merge(with: SurrogatesConfigurationUpdater(downloader: configDownloader).update())
                .merge(with: BloomFilterConfigurationUpdater(downloader: configDownloader).update())
                .collect()
                .timeout(.seconds(Constants.downloadTimeoutSeconds), scheduler: self.queue, options: nil, customError: { Error.timeout })
                .sink { completion in
                    print(#function, "sink completion")

                    if case .failure(let error) = completion {
                        os_log("Failed to complete configuration update %s", type: .error, error.localizedDescription)
                        self.tryAgainSoon()
                    } else {
                        self.tryAgainLater()
                    }

                    withExtendedLifetime(cancellable, {})
                    cancellable = nil
                    configDownloader.cancelAll()

                } receiveValue: { _ in
                    print(#function, "sink received value")
                    // no-op
                }
        }

    }

    private func isReadyToUpdate() -> Bool {
        return Date().timeIntervalSince(lastUpdateTime) > Constants.refreshPeriodSeconds
    }

    private func tryAgainLater() {
        lastUpdateTime = Date()
    }

    private func tryAgainSoon() {
        // Set the last update time to in the past so it triggers again sooner
        lastUpdateTime = Date(timeIntervalSinceNow: Constants.refreshPeriodSeconds - Constants.retryDelaySeconds)
    }

}
