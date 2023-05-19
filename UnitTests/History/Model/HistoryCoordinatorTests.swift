//
//  HistoryCoordinatorTests.swift
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

@MainActor
class HistoryCoordinatorTests: XCTestCase {

    func testWhenHistoryCoordinatorIsInitialized_ThenHistoryIsCleanedAndLoadedFromTheStore() {
        let (historyStoringMock, _) = HistoryCoordinator.aHistoryCoordinator

        XCTAssert(historyStoringMock.cleanOldCalled)
    }

    func testWhenAddVisitIsCalledBeforeHistoryIsLoadedFromStorage_ThenVisitIsIgnored() {
        let historyStoringMock = HistoryStoringMock()
        historyStoringMock.cleanOldResult = nil
        let historyCoordinator = HistoryCoordinator(historyStoring: historyStoringMock)

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)

        XCTAssertFalse(historyStoringMock.saveCalled)
    }

    func testWhenAddVisitIsCalledAndUrlIsNotPartOfHistoryYet_ThenNewHistoryEntryIsAdded() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)

        XCTAssert(historyCoordinator.history!.contains(where: { entry in
            entry.url == url
        }))

        historyCoordinator.commitChanges(url: url)
        XCTAssert(historyStoringMock.saveCalled)
    }

    func testWhenAddVisitIsCalledAndUrlIsAlreadyPartOfHistory_ThenNoEntryIsAdded() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)
        historyCoordinator.addVisit(of: url)

        XCTAssert(historyCoordinator.history!.count == 1)
        XCTAssert(historyCoordinator.history!.first!.numberOfVisits == 2)
        XCTAssert(historyCoordinator.history!.contains(where: { entry in
            entry.url == url
        }))

        historyCoordinator.commitChanges(url: url)
        XCTAssert(historyStoringMock.saveCalled)
    }

    func testWhenVisitIsAdded_ThenTitleIsNil() {
        let (_, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)

        XCTAssertNil(historyCoordinator.history!.first?.title)
    }

    func testUpdateTitleIfNeeded() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)

        let title1 = "Title 1"
        historyCoordinator.updateTitleIfNeeded(title: title1, url: url)
        XCTAssertEqual(historyCoordinator.history!.first?.title, title1)

        let title2 = "Title 2"
        historyCoordinator.updateTitleIfNeeded(title: title2, url: url)
        XCTAssertEqual(historyCoordinator.history!.first?.title, title2)

        historyCoordinator.updateTitleIfNeeded(title: title2, url: url)

        historyCoordinator.commitChanges(url: url)
        XCTAssert(historyStoringMock.saveCalled)
    }

    func testWhenTabChangesContent_commitHistoryIsCalled() {
        let historyCoordinatorMock = HistoryCoordinatingMock()
        let extensionBuilder = TestTabExtensionsBuilder(load: [HistoryTabExtensionMock.self])
        let tab = Tab(content: .url(.duckDuckGo), historyCoordinating: historyCoordinatorMock, extensionsBuilder: extensionBuilder, shouldLoadInBackground: false)
        tab.setContent(.url(.aboutDuckDuckGo))

        XCTAssert(historyCoordinatorMock.commitChangesCalled)
    }

    func testWhenHistoryIsBurning_ThenHistoryIsCleanedExceptFireproofDomains() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url1 = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url1)

        let url2 = URL(string: "https://test.duckduckgo.com")!
        historyCoordinator.addVisit(of: url2)

        let fireproofDomain = "wikipedia.org"
        let url3 = URL(string: "https://\(fireproofDomain)")!
        historyCoordinator.addVisit(of: url3)

        let url4 = URL(string: "https://subdomain.\(fireproofDomain)")!
        historyCoordinator.addVisit(of: url4)

        XCTAssert(historyCoordinator.history!.count == 4)

        let fireproofDomains = FireproofDomains(store: FireproofDomainsStoreMock())
        fireproofDomains.add(domain: fireproofDomain)
        historyCoordinator.burn(except: fireproofDomains) {
            XCTAssert(historyStoringMock.removeEntriesArray.count == 3)
        }
    }

    func testWhenBurningVisits_removesHistoryWhenVisitsCountHitsZero() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator
        historyStoringMock.removeEntriesResult = .success(())
        historyStoringMock.removeVisitsResult = .success(())

        let url1 = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url1)
        historyCoordinator.addVisit(of: url1)
        historyCoordinator.addVisit(of: url1)

        let visitsToBurn = Array(historyCoordinator.history!.first!.visits)

        let waiter = expectation(description: "Wait")
        historyCoordinator.burnVisits(visitsToBurn) {
            waiter.fulfill()
            XCTAssertEqual(historyStoringMock.removeEntriesArray.count, 1)
            XCTAssertEqual(historyStoringMock.removeEntriesArray.first!.url, url1)
        }
        waitForExpectations(timeout: 1.0)
    }

    func testWhenBurningVisits_removesVisitsFromTheStore() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator
        historyStoringMock.removeEntriesResult = .success(())
        historyStoringMock.removeVisitsResult = .success(())

        let url1 = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url1)
        historyCoordinator.addVisit(of: url1)
        historyCoordinator.addVisit(of: url1)

        let visitsToBurn = Array(historyCoordinator.history!.first!.visits)

        let waiter = expectation(description: "Wait")
        historyCoordinator.burnVisits(visitsToBurn) {
            waiter.fulfill()
            XCTAssertEqual(historyStoringMock.removeVisitsArray.count, 3)
        }
        waitForExpectations(timeout: 1.0)
    }

    func testWhenBurningVisits_DoesntDeleteHistoryBeforeVisits() {
        // Needs real store to catch assertion which can be raised by improper call ordering in the coordinator
        let context = CoreData.historyStoreContainer().newBackgroundContext()
        let historyStore = HistoryStore(context: context)
        let historyCoordinator = HistoryCoordinator(historyStoring: historyStore)

        let url1 = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url1)
        historyCoordinator.addVisit(of: url1)
        historyCoordinator.addVisit(of: url1)

        let url2 = URL(string: "https://test.duckduckgo.com")!
        historyCoordinator.addVisit(of: url2)
        historyCoordinator.addVisit(of: url2)
        historyCoordinator.addVisit(of: url2)

        let visitsToBurn = Array(historyCoordinator.history!.first!.visits)

        let waiter = expectation(description: "Wait")
        historyCoordinator.burnVisits(visitsToBurn) {
            waiter.fulfill()
            // Simply don't raise an assertion
        }
        waitForExpectations(timeout: 1.0)
    }

    func testWhenUrlIsMarkedAsFailedToLoad_ThenFailedToLoadFlagIsStored() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url)

        historyCoordinator.markFailedToLoadUrl(url)
        historyCoordinator.commitChanges(url: url)

        XCTAssertEqual(url, historyStoringMock.savedHistoryEntries.last?.url)
        XCTAssert(historyStoringMock.savedHistoryEntries.last?.failedToLoad ?? false)
    }

    func testWhenUrlIsMarkedAsFailedToLoadAndItIsVisitedAgain_ThenFailedToLoadFlagIsSetToFalse() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url)

        historyCoordinator.markFailedToLoadUrl(url)

        historyCoordinator.addVisit(of: url)

        historyCoordinator.commitChanges(url: url)
        XCTAssertEqual(url, historyStoringMock.savedHistoryEntries.last?.url)
        XCTAssertFalse(historyStoringMock.savedHistoryEntries.last?.failedToLoad ?? true)
    }

    func testWhenUrlHasNoTitle_ThenFetchingTitleReturnsNil() {
        let (_, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)

        let title = historyCoordinator.title(for: url)

        XCTAssertNil(title)
    }

    func testWhenUrlHasTitle_ThenTitleIsReturned() {
        let (_, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        let title = "DuckDuckGo"

        historyCoordinator.addVisit(of: url)
        historyCoordinator.updateTitleIfNeeded(title: title, url: url)
        let fetchedTitle = historyCoordinator.title(for: url)

        XCTAssertEqual(title, fetchedTitle)
    }

}

fileprivate extension HistoryCoordinator {

    static var aHistoryCoordinator: (HistoryStoringMock, HistoryCoordinator) {
        let historyStoringMock = HistoryStoringMock()
        historyStoringMock.cleanOldResult = .success(History())
        historyStoringMock.removeEntriesResult = .success(())
        let historyCoordinator = HistoryCoordinator(historyStoring: historyStoringMock)
        historyCoordinator.loadHistory()

        return (historyStoringMock, historyCoordinator)
    }

}
