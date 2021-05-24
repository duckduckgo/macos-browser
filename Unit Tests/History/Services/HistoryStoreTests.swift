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
        let container = NSPersistentContainer.createInMemoryPersistentContainer(modelName: "History", bundle: Bundle(for: type(of: self)))
        let context = container.viewContext
        let historyStore = HistoryStore(context: context)

        var historyEntry = HistoryEntry(identifier: UUID(), url: URL.duckDuckGo, title: "Test", numberOfVisits: 1, lastVisit: Date())
        let firstSavingExpectation = self.expectation(description: "Saving")
        save(entry: historyEntry, historyStore: historyStore, expectation: firstSavingExpectation)

        let newTitle = "New Title"
        historyEntry.title = newTitle
        let secondSavingExpectation = self.expectation(description: "Saving")
        save(entry: historyEntry, historyStore: historyStore, expectation: secondSavingExpectation)

        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.cleanAndReloadHistory(until: Date(timeIntervalSince1970: 0), except: [])
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

    func testWhenCleanAndReloadHistoryIsCalled_ThenOlderEntriesThanDateAreCleaned() {
        let container = NSPersistentContainer.createInMemoryPersistentContainer(modelName: "History", bundle: Bundle(for: type(of: self)))
        let context = container.viewContext
        let historyStore = HistoryStore(context: context)

        let oldHistoryEntry = HistoryEntry(identifier: UUID(),
                                      url: URL.duckDuckGo,
                                      title: nil,
                                      numberOfVisits: 1,
                                      lastVisit: Date.init(timeIntervalSince1970: 0))
        let firstSavingExpectation = self.expectation(description: "Saving")
        save(entry: oldHistoryEntry, historyStore: historyStore, expectation: firstSavingExpectation)

        let newHistoryEntryIdentifier = UUID()
        let newHistoryEntry = HistoryEntry(identifier: newHistoryEntryIdentifier,
                                           url: URL(string: "wikipedia.org")!,
                                           title: nil,
                                           numberOfVisits: 1,
                                           lastVisit: Date())
        let secondSavingExpectation = self.expectation(description: "Saving")
        save(entry: newHistoryEntry, historyStore: historyStore, expectation: secondSavingExpectation)

        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.cleanAndReloadHistory(until: Date(timeIntervalSince1970: 1), except: [])
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

    func testWhenCleanAndReloadHistoryIsCalledWithExceptions_ThenExceptionsMustNotBeCleaned() {
        let container = NSPersistentContainer.createInMemoryPersistentContainer(modelName: "History", bundle: Bundle(for: type(of: self)))
        let context = container.viewContext
        let historyStore = HistoryStore(context: context)

        let historyEntry = HistoryEntry(identifier: UUID(),
                                      url: URL.duckDuckGo,
                                      title: nil,
                                      numberOfVisits: 1,
                                      lastVisit: Date())
        let firstSavingExpectation = self.expectation(description: "Saving")
        save(entry: historyEntry, historyStore: historyStore, expectation: firstSavingExpectation)

        let exceptionHistoryEntryIdentifier = UUID()
        let exceptionHistoryEntry = HistoryEntry(identifier: exceptionHistoryEntryIdentifier,
                                           url: URL(string: "wikipedia.org")!,
                                           title: nil,
                                           numberOfVisits: 1,
                                           lastVisit: Date())
        let secondSavingExpectation = self.expectation(description: "Saving")
        save(entry: exceptionHistoryEntry, historyStore: historyStore, expectation: secondSavingExpectation)

        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.cleanAndReloadHistory(until: Date(), except: [exceptionHistoryEntry])
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
                XCTAssertEqual(history.first!.identifier, exceptionHistoryEntryIdentifier)
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

}
