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

import Combine

protocol ConfigurationDownloading {

    func createConfigurationUpdateJob() -> Future<Void, Never>

}

struct ConfigurationDownloadMeta {

    var etag: String
    var data: Data?

}

extension ConfigurationDownloading {

    func download(_ url: URL, currentEtag: String?, userAgent: String = "ddg_macos") -> Future<ConfigurationDownloadMeta, Never> {
        return Future { promise in
            var request = URLRequest(url: url)
            request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
            if let etag = currentEtag {
                request.addValue(etag, forHTTPHeaderField: "")
            }
            URLSession.shared.dataTask(with: url) { _, _, _ in
            }.resume()
        }
    }

}
