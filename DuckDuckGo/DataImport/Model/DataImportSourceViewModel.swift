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

struct DataImportSourceViewModel {

    let importSources: [DataImport.Source]
    var selectedSourceIndex: Int

    let onSelectedSourceChanged: (DataImport.Source) -> Void

    init(importSources: [DataImport.Source]? = nil, selectedSource: DataImport.Source, onSelectedSourceChanged: @escaping (DataImport.Source) -> Void) {

        self.importSources = importSources ?? DataImport.Source.allCases.filter(\.canImportData)
        assert(!self.importSources.isEmpty)

        self.selectedSourceIndex = self.importSources.firstIndex(of: selectedSource) ?? 0
        assert(self.importSources.indices.contains(selectedSourceIndex))

        self.onSelectedSourceChanged = onSelectedSourceChanged
    }

}
