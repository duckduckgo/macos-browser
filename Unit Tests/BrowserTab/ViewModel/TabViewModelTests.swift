//
//  TabViewModelTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

class TabViewModelTests: XCTestCase {

    var cancelables = Set<AnyCancellable>()

    // MARK: - AddressBarString

    func testWhenURLIsNilThenAddressBarStringIsEmpty() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)

        XCTAssertEqual(tabViewModel.addressBarString, "")
    }

    func testWhenURLIsSearchThenAddressBarStringIsTheQuery() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)

        let query = "query"
        let searchUrl = URL.makeSearchUrl(from: query)
        tab.url = searchUrl

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { addressBarString in
            XCTAssertEqual(addressBarString, query)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancelables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenURLIsRegularSiteThenAddressBarStringIsTheURLWithoutPrefix() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)

        let urlString = "spreadprivacy.com"
        tab.url = URL.makeURL(from: urlString)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { addressBarString in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancelables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - Title

    func testWhenURLIsNilThenTitleIsHome() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)

        XCTAssertEqual(tabViewModel.title, "Home")
    }

    func testWhenTabTitleIsNotNilThenTitleReflectsTabTitle() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)
        tab.url = URL.duckDuckGo
        let testTitle = "Test title"
        tab.title = testTitle

        let titleExpectation = expectation(description: "Title")

        tabViewModel.$title.debounce(for: 0.1, scheduler: RunLoop.main).sink { title in
            XCTAssertEqual(title, testTitle)
            titleExpectation.fulfill()
        } .store(in: &cancelables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenTabTitleIsNilThenTitleIsAddressBarString() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)
        tab.url = URL.duckDuckGo

        let titleExpectation = expectation(description: "Title")

        tabViewModel.$title.debounce(for: 0.1, scheduler: RunLoop.main).sink { title in
            XCTAssertEqual(title, tabViewModel.addressBarString)
            titleExpectation.fulfill()
        } .store(in: &cancelables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - Favicon

    func testWhenURLIsNilThenFaviconIsHomeFavicon() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)

        XCTAssertEqual(tabViewModel.favicon, TabViewModel.Favicon.home)
    }

    func testWhenTabFaviconIsNilThenFaviconIsDefaultFavicon() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)
        tab.url = URL.aNoFaviconSiteURL

        let faviconExpectation = expectation(description: "Favicon")

        tabViewModel.$favicon.debounce(for: 0.1, scheduler: RunLoop.main).sink { favicon in
            XCTAssertEqual(favicon, TabViewModel.Favicon.defaultFavicon)
            faviconExpectation.fulfill()
        } .store(in: &cancelables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenTabFaviconIsNotNilThenFaviconIsNotNil() {
        let tab = Tab()
        let tabViewModel = TabViewModel(tab: tab)
        tab.url = URL.duckDuckGo

        let faviconExpectation = expectation(description: "Favicon")

        tabViewModel.$favicon.debounce(for: 0.1, scheduler: RunLoop.main).sink { favicon in
            XCTAssertNotNil(favicon)
            XCTAssertNotEqual(favicon, TabViewModel.Favicon.defaultFavicon)
            XCTAssertNotEqual(favicon, TabViewModel.Favicon.home)
            faviconExpectation.fulfill()
        } .store(in: &cancelables)
        waitForExpectations(timeout: 1, handler: nil)
    }

}

fileprivate extension URL {

    static let aNoFaviconSiteURL = URL(string: "https://aktuality.sk")

}
