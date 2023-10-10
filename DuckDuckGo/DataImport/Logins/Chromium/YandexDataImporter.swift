//
//  YandexDataImporter.swift
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

final class YandexDataImporter: ChromiumDataImporter {

    override var processName: String {
        return "Yandex"
    }

    override var source: DataImport.Source {
        return .yandex
    }

    init(bookmarkImporter: BookmarkImporter) {
        let applicationSupport = URL.nonSandboxApplicationSupportDirectoryURL
        let defaultDataURL = applicationSupport.appendingPathComponent("Yandex/YandexBrowser/Default/")

        super.init(applicationDataDirectoryURL: defaultDataURL,
                   loginImporter: nil,
                   bookmarkImporter: bookmarkImporter,
                   faviconManager: FaviconManager.shared)
    }

    override func importData(types: [DataImport.DataType], from profile: DataImport.BrowserProfile?) -> DataImportResult<DataImport.Summary> {
        var result = super.importData(types: types.filter { $0 != .logins }, from: profile)

        if case .success(var summary) = result,
           types.contains(.logins) {

            summary.loginsResult = .awaited
            result = .success(summary)
        }

        return result
    }

}
