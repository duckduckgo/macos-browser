//
//  AccessibilityPreferencesTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class AccessibilityPreferencesTests: XCTestCase {

    let website1 = "https://www.bbc.com"
    let website2 = "https://duckduckgo.com"
    let website3 = "https://www.test.com"
    let website4 = "https://somesite.it"
    let domain1 = "bbc.com"
    let domain2 = "duckduckgo.com"
    let domain3 = "test.com"
    let domain4 = "somesite.it"
    let notificationName = AccessibilityPreferences.zoomPerWebsiteUpdated

    var zoom1: DefaultZoomValue!
    var zoom2: DefaultZoomValue!
    var zoom3: DefaultZoomValue!
    var zoom4: DefaultZoomValue!
    var mockPersistor: MockAccessibilityPreferencesPersistor!

    override func setUp() {
        mockPersistor = MockAccessibilityPreferencesPersistor()
        zoom1 = DefaultZoomValue.allCases.randomElement()!
        zoom2 = DefaultZoomValue.allCases.randomElement()!
        zoom3 = DefaultZoomValue.allCases.randomElement()!
        zoom4 = DefaultZoomValue.allCases.randomElement()!
    }

    override func tearDown() {
        mockPersistor = nil
        zoom1 = nil
        zoom2 = nil
    }

    func test_whenPreferencesInitialized_thenItLoadsPersistedDefaultPageZoom() {
        // GIVEN
        let randomZoom = DefaultZoomValue.allCases.randomElement()!
        mockPersistor.defaultPageZoom = randomZoom.rawValue

        // WHEN
        let accessibilityPreferences = AccessibilityPreferences(persistor: mockPersistor)

        // THEN
        XCTAssertEqual(accessibilityPreferences.defaultPageZoom, randomZoom)
    }

    func test_whenDefaultPageZoomUpdated_ThenPersistorUpdatesDefaultZoom() {
        // GIVEN
        let randomZoom = DefaultZoomValue.allCases.randomElement()!
        let accessibilityPreferences = AccessibilityPreferences(persistor: mockPersistor)

        // WHEN
        accessibilityPreferences.defaultPageZoom = randomZoom

        // THEN
        XCTAssertEqual(mockPersistor.defaultPageZoom, randomZoom.rawValue)
    }

    func test_whenZoomLevelPerWebsiteChangedInPreferences_thenThePersisterAndUserDefaultsZoomPerWebsiteValuesAreUpdated() {
        // GIVEN
        let notificationExpectation = expectation(forNotification: notificationName, object: nil, handler: nil)
        UserDefaultsWrapper<Any>.clearAll()
        let persister = AccessibilityPreferencesUserDefaultsPersistor()
        let model = AccessibilityPreferences(persistor: persister)

        // WHEN
        model.updateZoomPerWebsite(zoomLevel: zoom1, url: website1)
        model.updateZoomPerWebsite(zoomLevel: zoom2, url: website2)

        // THEN
        XCTAssertEqual(model.zoomPerWebsite(url: website1), zoom1)
        XCTAssertEqual(model.zoomPerWebsite(url: website2), zoom2)
        XCTAssertEqual(persister.zoomPerWebsite[domain1], zoom1.rawValue)
        XCTAssertEqual(persister.zoomPerWebsite[domain2], zoom2.rawValue)
        wait(for: [notificationExpectation], timeout: 1)
    }

    func test_whenBurningZoomLevels_thenOnlyFireproofSiteZoomLevelAreRetained() {
        // GIVEN
        let notificationExpectation = expectation(forNotification: notificationName, object: nil, handler: nil)
        UserDefaultsWrapper<Any>.clearAll()
        let persister = AccessibilityPreferencesUserDefaultsPersistor()
        let model = AccessibilityPreferences(persistor: persister)
        model.updateZoomPerWebsite(zoomLevel: zoom1, url: website1)
        model.updateZoomPerWebsite(zoomLevel: zoom2, url: website2)
        model.updateZoomPerWebsite(zoomLevel: zoom3, url: website3)
        model.updateZoomPerWebsite(zoomLevel: zoom4, url: website4)
        let fireProofDomains = MockFireproofDomains(domains: [website1, website3])

        // WHEN
        model.burnZoomLevels(except: fireProofDomains)

        // THEN
        XCTAssertEqual(model.zoomPerWebsite(url: website1), zoom1)
        XCTAssertNil(model.zoomPerWebsite(url: website2))
        XCTAssertEqual(model.zoomPerWebsite(url: website3), zoom3)
        XCTAssertNil(model.zoomPerWebsite(url: website4))
        XCTAssertEqual(persister.zoomPerWebsite[domain1], zoom1.rawValue)
        XCTAssertNil(persister.zoomPerWebsite[domain2])
        XCTAssertEqual(persister.zoomPerWebsite[domain3], zoom3.rawValue)
        XCTAssertNil(persister.zoomPerWebsite[domain4])
        wait(for: [notificationExpectation], timeout: 1)
    }

    func test_whenBurningZoomLevelsPerSites_thenZoomLevelOfTheSiteIsNotRetained() {
        // GIVEN
        let notificationExpectation = expectation(forNotification: notificationName, object: nil, handler: nil)
        UserDefaultsWrapper<Any>.clearAll()
        let persister = AccessibilityPreferencesUserDefaultsPersistor()
        let model = AccessibilityPreferences(persistor: persister)
        model.updateZoomPerWebsite(zoomLevel: zoom1, url: website1)
        model.updateZoomPerWebsite(zoomLevel: zoom2, url: website2)
        model.updateZoomPerWebsite(zoomLevel: zoom3, url: website3)
        model.updateZoomPerWebsite(zoomLevel: zoom4, url: website4)

        // WHEN
        model.burnZoomLevel(of: [domain1, domain4])

        // THEN
        XCTAssertNil(model.zoomPerWebsite(url: website1))
        XCTAssertEqual(model.zoomPerWebsite(url: website2), zoom2)
        XCTAssertEqual(model.zoomPerWebsite(url: website3), zoom3)
        XCTAssertNil(model.zoomPerWebsite(url: website4))
        XCTAssertNil(persister.zoomPerWebsite[domain1])
        XCTAssertEqual(persister.zoomPerWebsite[domain2], zoom2.rawValue)
        XCTAssertEqual(persister.zoomPerWebsite[domain3], zoom3.rawValue)
        XCTAssertNil(persister.zoomPerWebsite[domain4])
        wait(for: [notificationExpectation], timeout: 1)
    }

}

class MockAccessibilityPreferencesPersistor: AccessibilityPreferencesPersistor {
    var zoomPerWebsite: [String: CGFloat] = [:]
    var defaultPageZoom: CGFloat = DefaultZoomValue.percent100.rawValue
}

class MockFireproofDomains: FireproofDomains {
    init(domains: [String]) {
        super.init(store: FireproofDomainsStoreMock())
        for domain in domains {
            super.add(domain: domain)
        }
    }
}
