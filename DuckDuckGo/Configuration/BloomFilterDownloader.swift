//
//  BloomFilterDownloader.swift
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

class BloomFilterDownloader: ConfigurationDownloading {

    struct Locations {
        static let bloomFilterSpec = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json"
        static let bloomFilterBinary = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin"
        static let bloomFilterExcludedDomains = "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json"
    }
    
    func createConfigurationUpdateJob() -> Future<Void, Never> {
        return Future { promise in

            

        }
    }

}
