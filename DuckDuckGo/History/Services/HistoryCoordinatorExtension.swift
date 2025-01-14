//
//  HistoryCoordinatorExtension.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Common
import Foundation
import History

class HistoryStoreEventMapper: EventMapping<HistoryStore.HistoryStoreEvents> {
    public init() {
        super.init { event, error, _, _ in
            print(event)
//            switch event {
//            case .removeFailed:
//                Pixel.fire(pixel: .historyRemoveFailed, error: error)
//
//            case .reloadFailed:
//                Pixel.fire(pixel: .historyReloadFailed, error: error)
//
//            case .cleanEntriesFailed:
//                Pixel.fire(pixel: .historyCleanEntriesFailed, error: error)
//
//            case .cleanVisitsFailed:
//                Pixel.fire(pixel: .historyCleanVisitsFailed, error: error)
//
//            case .saveFailed:
//                Pixel.fire(pixel: .historySaveFailed, error: error)
//
//            case .insertVisitFailed:
//                Pixel.fire(pixel: .historyInsertVisitFailed, error: error)
//
//            case .removeVisitsFailed:
//                Pixel.fire(pixel: .historyRemoveVisitsFailed, error: error)
//            }
        }
    }

    override init(mapping: @escaping EventMapping<HistoryStore.HistoryStoreEvents>.Mapping) {
        fatalError("Use init()")
    }
}

extension HistoryCoordinator {

    static let shared = HistoryCoordinator(
        historyStoring: HistoryStore(
            context: HistoryDatabase.shared.db.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "History"),
            eventMapper: HistoryStoreEventMapper()
        )
    )

    func migrateModelV5toV6IfNeeded() {
        let defaults = MigrationDefaults()

        guard let historyDictionary = historyDictionary,
              !defaults.historyV5toV6Migration else {
            return
        }

        defaults.historyV5toV6Migration = true

        for entry in historyDictionary.values where entry.visits.isEmpty {
            entry.addOldVisit(date: entry.lastVisit)
            save(entry: entry)
        }
    }

    final class MigrationDefaults {
        @UserDefaultsWrapper(key: .historyV5toV6Migration, defaultValue: false)
        var historyV5toV6Migration: Bool
    }

}

extension HistoryEntry {

    func addOldVisit(date: Date) {
        let visit = Visit(date: date, historyEntry: self)
        visits.insert(visit)
    }

}
