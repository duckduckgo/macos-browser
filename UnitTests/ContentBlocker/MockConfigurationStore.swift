//
//  MockConfigurationStore.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Configuration

final class MockConfigurationStore: ConfigurationStoring {

    enum Error: Swift.Error {
        case mockError
    }

    var errorOnStoreData = false
    var errorOnStoreEtag = false

    var data: Data?
    var dataConfig: Configuration?

    var etag: String?
    var etagConfig: Configuration?

    func loadData(for: Configuration) -> Data? { data }

    func loadEtag(for: Configuration) -> String? { etag }

    func loadEmbeddedEtag(for configuration: Configuration) -> String? { nil }

    func saveData(_ data: Data, for config: Configuration) throws {
        if errorOnStoreData {
            throw Error.mockError
        }

        self.data = data
        self.dataConfig = config
    }

    func saveEtag(_ etag: String, for config: Configuration) throws {
        if errorOnStoreEtag {
            throw Error.mockError
        }

        self.etag = etag
        self.etagConfig = config
    }

    func log() { }

    func fileUrl(for configuration: Configuration) -> URL {
        return URL(string: "file///\(configuration.rawValue)")!
    }

}
