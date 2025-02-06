//
//  DataImportSourceViewModel.swift
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

struct DataImportSourceViewModel {

    let importSources: [DataImport.Source?]
    var selectedSourceIndex: Int

    init(importSources: [DataImport.Source]? = nil, selectedSource: DataImport.Source) {
        var importSources: [DataImport.Source?] = (importSources ?? DataImport.Source.allCases.filter(\.canImportData))

        // The CSV row is at the bottom of the picker, and requires a separator above it, but only if the item array isn't
        // empty (which would happen if there are no valid sources).
        for source in [DataImport.Source.onePassword8, .csv] {
            if let idx = importSources.lastIndex(of: source), idx > 0 {
                // separator
                importSources.insert(nil, at: idx)
            }
        }
        self.importSources = importSources

        assert(!self.importSources.isEmpty)

        self.selectedSourceIndex = self.importSources.firstIndex(of: selectedSource) ?? 0
        assert(self.importSources.indices.contains(selectedSourceIndex))
    }

}
