//
//  HistoryCoordinatingMock.swift
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
import BrowserServicesKit
import Common
import History
@testable import DuckDuckGo_Privacy_Browser

final class HistoryCoordinatingMock: HistoryCoordinating {

    func loadHistory(onCleanFinished: @escaping () -> Void) {
        onCleanFinished()
    }

    var history: BrowsingHistory?
    var allHistoryVisits: [Visit]?
    @Published private(set) var historyDictionary: [URL: HistoryEntry]?
    var historyDictionaryPublisher: Published<[URL: HistoryEntry]?>.Publisher { $historyDictionary }

    var addVisitCalled = false
    var visit: Visit?
    func addVisit(of url: URL, at date: Date) -> Visit? {
        addVisitCalled = true
        return visit
    }

    var updateTitleIfNeededCalled = false
    func updateTitleIfNeeded(title: String, url: URL) {
        updateTitleIfNeededCalled = true
    }

    var addBlockedTrackerCalled = false
    func addBlockedTracker(entityName: String, on url: URL) {
        addBlockedTrackerCalled = true
    }

    var commitChangesCalled = false
    func commitChanges(url: URL) {
        commitChangesCalled = true
    }

    var burnCalled = false
    func burn(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        burnCalled = true
        completion()
    }

    var burnAllCalled = false
    func burnAll(completion: @escaping () -> Void) {
        burnAllCalled = true
        completion()
    }

    var burnDomainsCalled = false
    func burnDomains(_ baseDomains: Set<String>, tld: Common.TLD, completion: @escaping (Set<URL>) -> Void) {
        burnDomainsCalled = true
        completion([])
    }

    var burnVisitsCalled = false
    func burnVisits(_ visits: [Visit], completion: @escaping () -> Void) {
        burnVisitsCalled = true
        completion()
    }

    var markFailedToLoadUrlCalled = false
    func markFailedToLoadUrl(_ url: URL) {
        markFailedToLoadUrlCalled = true
    }

    var titleForUrlCalled = false
    func title(for url: URL) -> String? {
        titleForUrlCalled = true
        return nil
    }

    var trackerFoundCalled = false
    func trackerFound(on: URL) {
        trackerFoundCalled = true
    }

    var removeUrlEntryCalled = false
    func removeUrlEntry(_ url: URL, completion: (((any Error)?) -> Void)?) {
        removeUrlEntryCalled = true
        completion?(nil)
    }

}
