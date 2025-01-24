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
import BrowserServicesKit

final class YandexDataImporter: ChromiumDataImporter {

    init(profile: DataImport.BrowserProfile, bookmarkImporter: BookmarkImporter) {
        super.init(profile: profile,
                   loginImporter: nil,
                   bookmarkImporter: bookmarkImporter,
                   faviconManager: FaviconManager.shared)
    }

    override var importableTypes: [DataImport.DataType] {
        return [.bookmarks]
    }

    override func importData(types: Set<DataImport.DataType>) -> DataImportTask {
        // logins will be imported from CSV
        return super.importData(types: types.filter { $0 != .passwords })
    }

    override func requiresKeychainPassword(for selectedDataTypes: Set<DataImport.DataType>) -> Bool {
        false
    }

}
