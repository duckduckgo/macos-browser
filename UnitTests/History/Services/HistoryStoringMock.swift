//
//  HistoryStoringMock.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser
import Combine
import History

final class HistoryStoringMock: HistoryStoring {

    enum HistoryStoringMockError: Error {
        case defaultError
    }

    var cleanOldCalled = false
    var cleanOldResult: Result<BrowsingHistory, Error>?
    func cleanOld(until date: Date) -> Future<BrowsingHistory, Error> {
        cleanOldCalled = true
        return Future { [weak self] promise in
            guard let cleanOldResult = self?.cleanOldResult else {
                promise(.failure(HistoryStoringMockError.defaultError))
                return
            }

            promise(cleanOldResult)
        }
    }

    func load() {
        // no-op
    }

    var removeEntriesCalled = false
    var removeEntriesArray = [HistoryEntry]()
    var removeEntriesResult: Result<Void, Error>?
    func removeEntries(_ entries: [HistoryEntry]) -> Future<Void, Error> {
        removeEntriesCalled = true
        removeEntriesArray = entries
        return Future { [weak self] promise in
            guard let removeEntriesResult = self?.removeEntriesResult else {
                promise(.failure(HistoryStoringMockError.defaultError))
                return
            }
            promise(removeEntriesResult)
        }
    }

    var removeVisitsCalled = false
    var removeVisitsArray = [Visit]()
    var removeVisitsResult: Result<Void, Error>?
    func removeVisits(_ visits: [Visit]) -> Future<Void, Error> {
        removeVisitsCalled = true
        removeVisitsArray = visits
        return Future { [weak self] promise in
            guard let removeVisitsResult = self?.removeVisitsResult else {
                promise(.failure(HistoryStoringMockError.defaultError))
                return
            }
            promise(removeVisitsResult)
        }
    }

    var saveCalled = false
    var savedHistoryEntries = [HistoryEntry]()
    func save(entry: HistoryEntry) -> Future<[(id: Visit.ID, date: Date)], Error> {
        saveCalled = true
        savedHistoryEntries.append(entry)
        for visit in entry.visits {
            // swiftlint:disable:next legacy_random
            visit.identifier = URL(string: "x-coredata://FBEAB2C4-8C32-4F3F-B34F-B79F293CDADD/VisitManagedObject/\(arc4random())")
        }

        return Future { promise in
            let result = entry.visits.map { ($0.identifier!, $0.date) }
            promise(.success(result))
        }
    }

}
