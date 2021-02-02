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

// https://theswiftdev.com/how-to-download-files-with-urlsession-using-combine-publishers-and-subscribers/
class ConfigurationManager {

    enum ConfigLocations: String {

        case bloomFilterSpec = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json"
        case trackerRadar = "https://staticcdn.duckduckgo.com/trackerblocking/v2.1/tds.json"
        case temporaryUnprotectedSites = "https://duckduckgo.com/contentblocking/trackers-whitelist-temporary.txt"

        // TODO https://github.com/duckduckgo/duckduckgo-privacy-extension/blob/develop/shared/data/surrogates.txt
        case surrogates = "https://duckduckgo.com/contentblocking.js?l=surrogates"

    }

    static let embeddedEtags: [ConfigLocations: String] = [

        .bloomFilterSpec: "",
        .trackerRadar: "",
        .temporaryUnprotectedSites: ""

    ]

    static let downloadTimeout = 60.0

    let queue = DispatchQueue(label: "Configuration Manager")

    func checkForDownloads() {
        queue.async {
            guard self.timeToCheck() else { return }

            Publishers.Zip3(self.beginDownload(.bloomFilterSpec), self.beginDownload(.trackerRadar), self.beginDownload(.temporaryUnprotectedSites)).sink(receiveValue: <#T##(((Download, Download, Download)) -> Void)##(((Download, Download, Download)) -> Void)##((Download, Download, Download)) -> Void#>)

            self.beginDownload(.bloomFilterSpec).sink { download in
                self.handleBloomFilterSpec(download)
            }

            self.beginDownload(.trackerRadar).sink { download in
                self.handleTrackerRadar(download)
            }

            self.beginDownload(.temporaryUnprotectedSites).sink { download in
                self.handleTemporaryUnprotectedSites(download)
            }

        }
    }

    private func timeToCheck() -> Bool {
        return false
    }

    private func beginDownload(_ location: ConfigLocations) -> Just<Download> {
        return Just(Download(etag: "", data: Data()))
    }

    private func handleBloomFilterSpec(_ download: Download) {
    }

    private func handleTrackerRadar(_ download: Download) {
    }

    private func handleTemporaryUnprotectedSites(_ download: Download) {
    }

    struct Download {

        let etag: String
        let data: Data

    }

}

class BloomFilterFetcher {

    static let bloomFilterBinary = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin"
    static let bloomFilterExcludedDomains = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json"

}
