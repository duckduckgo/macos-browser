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
@testable import DuckDuckGo_Privacy_Browser

final class HistoryCoordinatingMock: HistoryCoordinating {

    var history: History?

    var addVisitCalled = false
    func addVisit(of url: URL) {
        addVisitCalled = true
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

    var burnDomainsCalled = false
    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void) {
        burnDomainsCalled = true
        completion()
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

}
