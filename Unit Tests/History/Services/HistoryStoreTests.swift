//
//  HistoryStoreTests.swift
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

final class HistoryStoreTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        registerDependency(&Tab.Dependencies.faviconManagement, value: FaviconManagerMock())
    }

    func save(entry: HistoryEntry, historyStore: HistoryStore, expectation: XCTestExpectation) {
        historyStore.save(entry: entry)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Saving of history entry failed - \(error.localizedDescription)")
                }
            } receiveValue: {}
            .store(in: &cancellables)
    }

    func testWhenHistoryEntryIsSavedMultipleTimes_ThenTheNewestValueMustBeLoadedFromStore() {
        let container = CoreData.createInMemoryPersistentContainer(modelName: "History", bundle: Bundle(for: type(of: self)))
        let context = container.viewContext
        let historyStore = HistoryStore(context: context)

        let historyEntry = HistoryEntry(identifier: UUID(),
                                        url: URL.duckDuckGo,
                                        title: "Test",
                                        numberOfVisits: 1,
                                        lastVisit: Date(),
                                        visits: [])
        let firstSavingExpectation = self.expectation(description: "Saving")
        save(entry: historyEntry, historyStore: historyStore, expectation: firstSavingExpectation)

        let newTitle = "New Title"
        historyEntry.title = newTitle
        let secondSavingExpectation = self.expectation(description: "Saving")
        save(entry: historyEntry, historyStore: historyStore, expectation: secondSavingExpectation)

        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.cleanOld(until: Date(timeIntervalSince1970: 0))
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    loadingExpectation.fulfill()
                case .failure(let error):
                    XCTFail("Loading of history failed - \(error.localizedDescription)")
                }
            } receiveValue: { history in
                XCTAssertEqual(history.count, 1)
                XCTAssertEqual(history.first!.title, newTitle)
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenCleanOldIsCalled_ThenOlderEntriesThanDateAreCleaned() {
        let container = CoreData.createInMemoryPersistentContainer(modelName: "History", bundle: Bundle(for: type(of: self)))
        let context = container.viewContext
        let historyStore = HistoryStore(context: context)

        let oldHistoryEntry = HistoryEntry(identifier: UUID(),
                                           url: URL.duckDuckGo,
                                           title: nil,
                                           numberOfVisits: 1,
                                           lastVisit: Date.init(timeIntervalSince1970: 0),
                                           visits: [])
        let firstSavingExpectation = self.expectation(description: "Saving")
        save(entry: oldHistoryEntry, historyStore: historyStore, expectation: firstSavingExpectation)

        let newHistoryEntryIdentifier = UUID()
        let newHistoryEntry = HistoryEntry(identifier: newHistoryEntryIdentifier,
                                           url: URL(string: "wikipedia.org")!,
                                           title: nil,
                                           numberOfVisits: 1,
                                           lastVisit: Date(),
                                           visits: [])
        let secondSavingExpectation = self.expectation(description: "Saving")
        save(entry: newHistoryEntry, historyStore: historyStore, expectation: secondSavingExpectation)

        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.cleanOld(until: Date(timeIntervalSince1970: 1))
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    loadingExpectation.fulfill()
                case .failure(let error):
                    XCTFail("Loading of history failed - \(error.localizedDescription)")
                }
            } receiveValue: { history in
                XCTAssertEqual(history.count, 1)
                XCTAssertEqual(history.first!.identifier, newHistoryEntryIdentifier)
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenRemoveEntriesIsCalled_ThenEntriesMustBeCleaned() {
        let container = CoreData.createInMemoryPersistentContainer(modelName: "History", bundle: Bundle(for: type(of: self)))
        let context = container.viewContext
        let historyStore = HistoryStore(context: context)

        let notToRemoveIdentifier = UUID()
        let historyEntry = HistoryEntry(identifier: notToRemoveIdentifier,
                                        url: URL.duckDuckGo,
                                        title: nil,
                                        numberOfVisits: 1,
                                        lastVisit: Date(),
                                        visits: [])
        let firstSavingExpectation = self.expectation(description: "Saving")
        save(entry: historyEntry, historyStore: historyStore, expectation: firstSavingExpectation)

        let toRemoveHistoryEntry = HistoryEntry(identifier: UUID(),
                                                url: URL(string: "wikipedia.org")!,
                                                title: nil,
                                                numberOfVisits: 1,
                                                lastVisit: Date(),
                                                visits: [])
        let secondSavingExpectation = self.expectation(description: "Saving")
        save(entry: toRemoveHistoryEntry, historyStore: historyStore, expectation: secondSavingExpectation)

        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.removeEntries([toRemoveHistoryEntry])
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    loadingExpectation.fulfill()
                case .failure(let error):
                    XCTFail("Loading of history failed - \(error.localizedDescription)")
                }
            } receiveValue: {}
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

}

fileprivate extension HistoryEntry {

    convenience init(identifier: UUID, url: URL, title: String?, numberOfVisits: Int, lastVisit: Date, visits: [Visit]) {
        self.init(identifier: identifier,
                  url: url,
                  title: title,
                  failedToLoad: false,
                  numberOfTotalVisits: numberOfVisits,
                  lastVisit: lastVisit,
                  visits: Set(visits),
                  numberOfTrackersBlocked: 0,
                  blockedTrackingEntities: .init(),
                  trackersFound: false)
    }

}
