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
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertNil(historyCoordinator.history)
        XCTAssertFalse(historyStoringMock.saveCalled)
    }

    func testWhenAddVisitIsCalledAndUrlIsNotPartOfHistoryYet_ThenNewHistoryEntryIsAdded() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssert(historyCoordinator.history!.contains(where: { entry in
            entry.url == url
        }))

        historyCoordinator.commitChanges(url: url)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssert(historyStoringMock.saveCalled)
    }

    func testWhenAddVisitIsCalledAndUrlIsAlreadyPartOfHistory_ThenNoEntryIsAdded() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)
        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssert(historyCoordinator.history!.count == 1)
        XCTAssert(historyCoordinator.history!.first!.numberOfVisits == 2)
        XCTAssert(historyCoordinator.history!.contains(where: { entry in
            entry.url == url
        }))

        historyCoordinator.commitChanges(url: url)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssert(historyStoringMock.saveCalled)
    }

    func testWhenVisitIsAdded_ThenTitleIsNil() {
        let (_, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertNil(historyCoordinator.history!.first?.title)
    }

    func testUpdateTitleIfNeeded() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        let title1 = "Title 1"
        historyCoordinator.updateTitleIfNeeded(title: title1, url: url)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(historyCoordinator.history!.first?.title, title1)

        let title2 = "Title 2"
        historyCoordinator.updateTitleIfNeeded(title: title2, url: url)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(historyCoordinator.history!.first?.title, title2)

        historyCoordinator.updateTitleIfNeeded(title: title2, url: url)
        Thread.sleep(forTimeInterval: 0.05)

        historyCoordinator.commitChanges(url: url)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssert(historyStoringMock.saveCalled)
    }

    func testWhenTabChangesContent_commitHistoryIsCalled() {
        let historyCoordinatorMock = HistoryCoordinatingMock()
        let tab = Tab(content: .url(.duckDuckGo), historyCoordinating: historyCoordinatorMock)
        tab.setContent(.url(.aboutDuckDuckGo))

        XCTAssert(historyCoordinatorMock.commitChangesCalled)
    }

    func testWhenHistoryIsBurning_ThenHistoryIsCleanedExceptFireproofDomains() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url1 = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url1)
        Thread.sleep(forTimeInterval: 0.1)

        let url2 = URL(string: "https://test.duckduckgo.com")!
        historyCoordinator.addVisit(of: url2)
        Thread.sleep(forTimeInterval: 0.1)

        let fireproofDomain = "wikipedia.org"
        let url3 = URL(string: "https://\(fireproofDomain)")!
        historyCoordinator.addVisit(of: url3)
        Thread.sleep(forTimeInterval: 0.1)

        let url4 = URL(string: "https://subdomain.\(fireproofDomain)")!
        historyCoordinator.addVisit(of: url4)
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssert(historyCoordinator.history!.count == 4)

        let fireproofDomains = FireproofDomains(store: FireproofDomainsStoreMock())
        fireproofDomains.add(domain: fireproofDomain)
        historyCoordinator.burn(except: fireproofDomains) {
            XCTAssert(historyStoringMock.removeEntriesArray.count == 3)
        }
    }

    func testWhenUrlIsMarkedAsFailedToLoad_ThenFailedToLoadFlagIsStored() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        historyCoordinator.markFailedToLoadUrl(url)
        historyCoordinator.commitChanges(url: url)
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertEqual(url, historyStoringMock.savedHistoryEntries.last?.url)
        XCTAssert(historyStoringMock.savedHistoryEntries.last?.failedToLoad ?? false)
    }

    func testWhenUrlIsMarkedAsFailedToLoadAndItIsVisitedAgain_ThenFailedToLoadFlagIsSetToFalse() {
        let (historyStoringMock, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL(string: "https://duckduckgo.com")!
        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        historyCoordinator.markFailedToLoadUrl(url)
        Thread.sleep(forTimeInterval: 0.1)

        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        historyCoordinator.commitChanges(url: url)
        XCTAssertEqual(url, historyStoringMock.savedHistoryEntries.last?.url)
        XCTAssertFalse(historyStoringMock.savedHistoryEntries.last?.failedToLoad ?? true)
    }

    func testWhenUrlHasNoTitle_ThenFetchingTitleReturnsNil() {
        let (_, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        let title = historyCoordinator.title(for: url)
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertNil(title)
    }

    func testWhenUrlHasTitle_ThenTitleIsReturned() {
        let (_, historyCoordinator) = HistoryCoordinator.aHistoryCoordinator

        let url = URL.duckDuckGo
        let title = "DuckDuckGo"

        historyCoordinator.addVisit(of: url)
        Thread.sleep(forTimeInterval: 0.1)

        historyCoordinator.updateTitleIfNeeded(title: title, url: url)
        Thread.sleep(forTimeInterval: 0.1)

        let fetchedTitle = historyCoordinator.title(for: url)
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertEqual(title, fetchedTitle)
    }

}

fileprivate extension HistoryCoordinator {

    static var aHistoryCoordinator: (HistoryStoringMock, HistoryCoordinator) {
        let historyStoringMock = HistoryStoringMock()
        historyStoringMock.cleanOldResult = .success(History())
        historyStoringMock.removeEntriesResult = .success(())
        let historyCoordinator = HistoryCoordinator(historyStoring: historyStoringMock)
        Thread.sleep(forTimeInterval: 0.1)

        return (historyStoringMock, historyCoordinator)
    }

}
