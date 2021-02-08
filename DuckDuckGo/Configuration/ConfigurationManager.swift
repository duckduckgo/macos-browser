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

class ConfigurationManager {

    enum Error: Swift.Error {

        case unknown

    }

    static let queue = DispatchQueue(label: "Configuration Manager")

    static let downloadTimeout = 60.0 * 5

    var cancellable: AnyCancellable?

    func checkForDownloads() {
        Self.queue.async {
            guard self.isReadyToUpdate() else { return }

            let configDownloader: ConfigurationDownloader = DefaultConfigurationDownloader()

            // This is a serial queue but some of the calls below are async, so we want to wait for everything to finish before allowing
            //  these API calls again.
            let group = DispatchGroup()
            group.enter()

            self.cancellable = BloomFilterConfigurationUpdater(downloader: configDownloader).future()
                .merge(with: TrackerRadarConfigurationUpdater(downloader: configDownloader).future())
                .merge(with: TemporaryUnprotectedSitesConfigurationUpdater(downloader: configDownloader).future())
                .merge(with: SurrogatesConfigurationUpdater(downloader: configDownloader).future())
                .collect()
                .sink { _ in
                    self.updateCompleted()
                    group.leave()
                }

            if group.wait(timeout: .now() + Self.downloadTimeout) == .timedOut {
                // TODO log it
            }

            configDownloader.cancelAll()
        }
    }

    private func isReadyToUpdate() -> Bool {
        return true
    }

    private func updateCompleted() {

    }

}
