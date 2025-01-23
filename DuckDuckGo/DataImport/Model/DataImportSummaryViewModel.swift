//
//  DataImportSummaryViewModel.swift
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

struct DataImportSummaryViewModel {
    typealias Source = DataImport.Source
    typealias DataType = DataImport.DataType
    typealias DataTypeImportResult = DataImportViewModel.DataTypeImportResult
    typealias DataTypeSummary = DataImport.DataTypeSummary

    enum SummaryKind {
        // total
        case results
        // one data type only
        case importComplete(DataType)
        // file import per data type
        case fileImportComplete(DataType)
    }
    let summaryKind: SummaryKind
    let results: [DataTypeImportResult]

    init(source: Source, isFileImport: Bool = false, results: [DataTypeImportResult], dataTypes: Set<DataType>? = nil) {
        let dataTypes = dataTypes ?? Set(results.map(\.dataType))
        assert(!dataTypes.isEmpty)

        if dataTypes.count > 1 || dataTypes.contains(where: { dataType in
            // always “results” if there‘s a failure
            results.last(where: { $0.dataType == dataType })?.result.isSuccess == false
        }) {
            self.summaryKind = .results

        } else {
            let dataType = dataTypes.first ?? .bookmarks

            self.summaryKind = isFileImport ? .fileImportComplete(dataType) : .importComplete(dataType)
        }

        self.results = DataType.allCases.compactMap { dataType in
            dataTypes.contains(dataType) ? results.last(where: { $0.dataType == dataType }) : nil
        }
    }
}

extension DataImportSummaryViewModel {
    func resultsFiltered(by dataType: DataType) -> [DataTypeImportResult] {
        results.filter { $0.dataType == dataType }
    }
}
