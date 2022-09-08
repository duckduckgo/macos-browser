//
//  CoreDataHistoryImporter.swift
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

final class CoreDataHistoryImporter: HistoryImporter {
    private let historyCoordinator: HistoryCoordinating

    init(historyCoordinator: HistoryCoordinating) {
        self.historyCoordinator = historyCoordinator
    }

    func importHistory(_ visits: [ImportedHistoryVisit]) async -> HistoryImportResult {
        return await withCheckedContinuation { continuation in
            historyCoordinator.importVisits(visits) {
                continuation.resume(returning: .init(successful: 0, failed: 0))
            }
        }
    }

}
