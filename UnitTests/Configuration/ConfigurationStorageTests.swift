//
//  ConfigurationStorageTests.swift
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

import XCTest
import Combine
import Configuration
@testable import DuckDuckGo_Privacy_Browser

final class ConfigurationStorageTests: XCTestCase {

    var configurationStore: ConfigurationStore = ConfigurationStore()

    override func tearDown() {
        super.tearDown()
        for config in Configuration.allCases {
            let url = configurationStore.fileUrl(for: config)
            try? FileManager.default.removeItem(at: url)
        }
    }

    func test_when_data_is_saved_for_config_then_it_can_be_loaded_correctly() {
        for config in Configuration.allCases {
            let uuid = UUID().uuidString
            try? configurationStore.saveData(uuid.data(using: .utf8)!, for: config)
            XCTAssertEqual(uuid, configurationStore.loadData(for: config)?.utf8String())
        }
    }

    func test_when_etag_is_saved_for_config_then_it_can_be_loaded_correctly() {
        for config in Configuration.allCases {
            let etag = UUID().uuidString
            try? configurationStore.saveEtag(etag, for: config)
            XCTAssertEqual(etag, configurationStore.loadEtag(for: config))
        }
    }

}
