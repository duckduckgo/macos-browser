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
import class BrowserServicesKit.CoreDataDatabase

final class HistoryStoreTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()
    
    private var database: CoreDataDatabase!
    private var location: URL!
    
    override func setUp() {
        let model = CoreDataDatabase.loadModel(from: .main, named: "History")!
        location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        database = CoreDataDatabase(name: className, containerLocation: location, model: model)
        database.loadStore { _, error in
            if let e = error {
                XCTFail("Could not load store: \(e.localizedDescription)")
            }
        }
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try FileManager.default.removeItem(at: location)
        database = nil
        location = nil
        cancellables.removeAll()
    }

    func testWhenHistoryEntryIsSavedMultipleTimes_ThenTheNewestValueMustBeLoadedFromStore() {
        let context = database.makeContext(concurrencyType: .mainQueueConcurrencyType)
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
        let context = database.makeContext(concurrencyType: .mainQueueConcurrencyType)
        let historyStore = HistoryStore(context: context)

        let toBeKeptIdentifier = UUID()
        let newHistoryEntry = HistoryEntry(identifier: toBeKeptIdentifier,
                                           url: URL(string: "wikipedia.org")!,
                                           title: nil,
                                           numberOfVisits: 1,
                                           lastVisit: Date(),
                                           visits: [])
        let savingExpectation = self.expectation(description: "Saving")
        save(entry: newHistoryEntry, historyStore: historyStore, expectation: savingExpectation)
        
        var toBeDeleted: [HistoryEntry] = []
        for i in 0..<150 {
            let identifier = UUID()
            let visitDate = Date(timeIntervalSince1970: 1000.0 * Double(i))
            let visit = Visit(date: visitDate)
            let toRemoveHistoryEntry = HistoryEntry(identifier: identifier,
                                                    url: URL(string: "wikipedia.org/\(identifier)")!,
                                                    title: nil,
                                                    numberOfVisits: 1,
                                                    lastVisit: visitDate,
                                                    visits: [visit])
            visit.historyEntry = toRemoveHistoryEntry
            save(entry: toRemoveHistoryEntry, historyStore: historyStore)
            toBeDeleted.append(toRemoveHistoryEntry)
        }

        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.cleanOld(until: .weekAgo)
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
                XCTAssertEqual(history.first!.identifier, toBeKeptIdentifier)
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenRemoveEntriesIsCalled_ThenEntriesMustBeCleaned() {
        let context = database.makeContext(concurrencyType: .mainQueueConcurrencyType)
        let historyStore = HistoryStore(context: context)

        let visitDate = Date(timeIntervalSince1970: 1234)
        let visit = Visit(date: visitDate)
        let firstSavingExpectation = self.expectation(description: "Saving")
        let toBeKept = saveNewHistoryEntry(including: [visit], lastVisit: visitDate, historyStore: historyStore, expectation: firstSavingExpectation)

        var toBeDeleted: [HistoryEntry] = []
        for _ in 0..<150 {
            let identifier = UUID()
            let visitDate = Date()
            let visit = Visit(date: visitDate)
            let toRemoveHistoryEntry = HistoryEntry(identifier: identifier,
                                                    url: URL(string: "wikipedia.org/\(identifier)")!,
                                                    title: nil,
                                                    numberOfVisits: 1,
                                                    lastVisit: visitDate,
                                                    visits: [visit])
            visit.historyEntry = toRemoveHistoryEntry
            save(entry: toRemoveHistoryEntry, historyStore: historyStore)
            toBeDeleted.append(toRemoveHistoryEntry)
        }

        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.removeEntries(toBeDeleted)
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
        
        context.performAndWait {
            let request = DuckDuckGo_Privacy_Browser.HistoryEntryManagedObject.fetchRequest()
            do {
                let results = try context.fetch(request)
                XCTAssertEqual(results.first?.identifier, toBeKept.identifier)
                XCTAssertEqual(results.count, 1)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    func testWhenRemoveVisitsIsCalled_ThenVisitsMustBeCleaned() {
        let context = database.makeContext(concurrencyType: .mainQueueConcurrencyType)
        let historyStore = HistoryStore(context: context)

        let visitDate = Date(timeIntervalSince1970: 1234)
        let toBeKept = Visit(date: visitDate)
        let firstSavingExpectation = self.expectation(description: "Saving")
        let toBeKeptsHistory = saveNewHistoryEntry(including: [toBeKept], lastVisit: visitDate, historyStore: historyStore, expectation: firstSavingExpectation)

        var toBeDeleted: [Visit] = []
        var historiesToPreventFromDeallocation = [HistoryEntry]()
        let addVisitsToEntry = { [weak self] (visits: [Visit]) in
            guard let self = self else { return }
            let history = self.saveNewHistoryEntry(including: visits, lastVisit: visits.last!.date, historyStore: historyStore)
            historiesToPreventFromDeallocation.append(history)
        }
        
        for _ in 0..<3 {
            var visits = [Visit]()
            for j in 0..<50 {
                let visitDate = Date(timeIntervalSince1970: Double(j))
                let visit = Visit(date: visitDate)
                visits.append(visit)
                toBeDeleted.append(visit)
            }
            addVisitsToEntry(visits)
        }

        let loadingExpectation = self.expectation(description: "Loading")
        withExtendedLifetime(historiesToPreventFromDeallocation) { _ in
            historyStore.removeVisits(toBeDeleted)
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
        
        context.performAndWait {
            let request = DuckDuckGo_Privacy_Browser.VisitManagedObject.fetchRequest()
            do {
                let results = try context.fetch(request)
                XCTAssertEqual(results.first?.historyEntry?.identifier, toBeKeptsHistory.identifier)
                XCTAssertEqual(results.first?.date, toBeKept.date)
                XCTAssertEqual(results.count, 1)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    func testWhenCleanOldIsCalled_ThenFollowingSaveShouldSucceed() {
        let context = database.makeContext(concurrencyType: .mainQueueConcurrencyType)
        let historyStore = HistoryStore(context: context)
        
        let oldVisitDate = Date(timeIntervalSince1970: 0)
        let newVisitDate = Date(timeIntervalSince1970: 12345)
        
        let oldVisit = Visit(date: oldVisitDate)
        let newVisit = Visit(date: newVisitDate)

        let firstSavingExpectation = self.expectation(description: "Saving")
        saveNewHistoryEntry(including: [oldVisit, newVisit],
                            lastVisit: newVisitDate,
                            historyStore: historyStore,
                            expectation: firstSavingExpectation)
        
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
                for entry in history {
                    XCTAssertEqual(entry.visits.count, 1)
                }
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 2, handler: nil)

        let secondSavingExpectation = self.expectation(description: "Saving")
        // This should not fail, but apparently internal version of objects is broken after BatchDelete request causing merge failure.
        saveNewHistoryEntry(including: [oldVisit, newVisit],
                            lastVisit: newVisitDate,
                            historyStore: historyStore,
                            expectation: secondSavingExpectation)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testWhenRemoveVisitsIsCalled_ThenFollowingSaveShouldSucceed() {
        let context = database.makeContext(concurrencyType: .mainQueueConcurrencyType)
        let historyStore = HistoryStore(context: context)
        
        let oldVisitDate = Date(timeIntervalSince1970: 0)
        let newVisitDate = Date(timeIntervalSince1970: 12345)
        
        let oldVisit = Visit(date: oldVisitDate)
        let newVisit = Visit(date: newVisitDate)

        let firstSavingExpectation = self.expectation(description: "Saving")
        let history = saveNewHistoryEntry(including: [oldVisit, newVisit],
                                          lastVisit: newVisitDate,
                                          historyStore: historyStore,
                                          expectation: firstSavingExpectation)

        withExtendedLifetime(history) { _ in
            let loadingExpectation = self.expectation(description: "Loading")
            historyStore.removeVisits([oldVisit])
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    switch completion {
                    case .finished:
                        loadingExpectation.fulfill()
                    case .failure(let error):
                        XCTFail("Loading of history failed - \(error.localizedDescription)")
                    }
                } receiveValue: { _ in }
                .store(in: &cancellables)
            waitForExpectations(timeout: 2, handler: nil)
        }
        
        let secondSavingExpectation = self.expectation(description: "Saving")
        saveNewHistoryEntry(including: [oldVisit, newVisit],
                            lastVisit: newVisitDate,
                            historyStore: historyStore,
                            expectation: secondSavingExpectation)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testWhenRemoveEntriesIsCalled_ThenFollowingSaveShouldSucceed() {
        let context = database.makeContext(concurrencyType: .mainQueueConcurrencyType)
        let historyStore = HistoryStore(context: context)
        
        let oldVisitDate = Date(timeIntervalSince1970: 0)
        let newVisitDate = Date(timeIntervalSince1970: 12345)
        
        let oldVisit = Visit(date: oldVisitDate)
        let newVisit = Visit(date: newVisitDate)

        let firstSavingExpectation = self.expectation(description: "Saving")
        let historyEntry = saveNewHistoryEntry(including: [oldVisit, newVisit],
                                               lastVisit: newVisitDate,
                                               historyStore: historyStore,
                                               expectation: firstSavingExpectation)
        
        let loadingExpectation = self.expectation(description: "Loading")
        historyStore.removeEntries([historyEntry])
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    loadingExpectation.fulfill()
                case .failure(let error):
                    XCTFail("Loading of history failed - \(error.localizedDescription)")
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)

        waitForExpectations(timeout: 2, handler: nil)
        
        let secondSavingExpectation = self.expectation(description: "Saving")
        saveNewHistoryEntry(including: [oldVisit, newVisit],
                            lastVisit: newVisitDate,
                            historyStore: historyStore,
                            expectation: secondSavingExpectation)
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    @discardableResult
    private func saveNewHistoryEntry(including visits: [Visit], lastVisit: Date, historyStore: HistoryStore, expectation: XCTestExpectation? = nil) -> HistoryEntry {
        let historyEntry = HistoryEntry(identifier: UUID(),
                                        url: URL.duckDuckGo,
                                        title: nil,
                                        numberOfVisits: visits.count,
                                        lastVisit: lastVisit,
                                        visits: visits)
        for visit in visits {
            visit.historyEntry = historyEntry
        }
        save(entry: historyEntry, historyStore: historyStore, expectation: expectation)
        return historyEntry
    }

    private func save(entry: HistoryEntry, historyStore: HistoryStore, expectation: XCTestExpectation? = nil) {
        historyStore.save(entry: entry)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    expectation?.fulfill()
                case .failure(let error):
                    XCTFail("Saving of history entry failed - \(error.localizedDescription)")
                }
            } receiveValue: {}
            .store(in: &cancellables)
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
