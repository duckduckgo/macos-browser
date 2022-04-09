//
//  AppPrivacyConfigurationDataProvider.swift
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

import BrowserServicesKit
import Foundation

final class AppPrivacyConfigurationDataProvider: EmbeddedDataProvider {

    public enum Constants {
        public static let embeddedConfigETag = "a18405692732951d628f86b7ba1a1e1d"
        public static let embeddedConfigurationSHA = "ef78422d8a7b1a324d6cbdb70b3605eca4934aa0b090a25548e51e42cffda53e"
    }

    var embeddedDataEtag: String {
        Constants.embeddedConfigETag
    }

    var embeddedData: Data {
        Self.loadEmbeddedAsData()
    }

    static var embeddedUrl: URL {
        Bundle.main.url(forResource: "macos-config", withExtension: "json")!
    }

    static func loadEmbeddedAsData() -> Data {
        let json = try? Data(contentsOf: embeddedUrl)
        return json!
    }
}
