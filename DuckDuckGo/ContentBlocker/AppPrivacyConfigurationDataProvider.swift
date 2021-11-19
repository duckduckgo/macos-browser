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

import Foundation
import BrowserServicesKit

final class AppPrivacyConfigurationDataProvider: PrivacyConfigurationDataProvider {
    // TODO - test and etag updates
    public struct Constants {
        public static let embeddedConfigETag = "e6214cfd463faa4d9d00ab357539aa43"
        public static let embeddedConfigurationSHA = "S2/XfJs7hKiPAX1h1j8w06g/3N5vOVLi4BuDWcEQCus="
    }

    var embeddedPrivacyConfigEtag: String {
        return Constants.embeddedConfigETag
    }

    var embeddedPrivacyConfig: Data {
        return Self.loadEmbeddedAsData()
    }

    static var embeddedUrl: URL {
        return Bundle.main.url(forResource: "macos-config", withExtension: "json")!
    }

    static func loadEmbeddedAsData() -> Data {
        let json = try? Data(contentsOf: embeddedUrl)
        return json!
    }
}
