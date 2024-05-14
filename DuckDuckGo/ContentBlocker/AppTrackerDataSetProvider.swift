//
//  AppTrackerDataSetProvider.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class AppTrackerDataSetProvider: EmbeddedDataProvider {

    public struct Constants {
        public static let embeddedDataETag = "\"ef8ebcc98d8abccca793c7e04422b160\""
        public static let embeddedDataSHA = "e2e8e5e191df54227222fbb0545a7eb8634b1156a69182323981bb6aed2c639d"
    }

    var embeddedDataEtag: String {
        return Constants.embeddedDataETag
    }

    var embeddedData: Data {
        return Self.loadEmbeddedAsData()
    }

    static var embeddedUrl: URL {
        return Bundle.main.url(forResource: "trackerData", withExtension: "json")!
    }

    static func loadEmbeddedAsData() -> Data {
        return Data()
    }
}
