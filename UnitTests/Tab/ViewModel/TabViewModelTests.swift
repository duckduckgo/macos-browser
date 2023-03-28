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

final class TabViewModelTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    // MARK: - Can reload

    func testWhenURLIsNilThenCanReloadIsFalse() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertFalse(tabViewModel.canReload)
    }

    func testWhenURLIsNotNilThenCanReloadIsTrue() {
        let tabViewModel = TabViewModel.forTabWithURL(.duckDuckGo)

        let canReloadExpectation = expectation(description: "Can reload")
        tabViewModel.$canReload.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssert(tabViewModel.canReload)
            canReloadExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 2, handler: nil)
    }

    // MARK: - AddressBarString

    func testWhenURLIsNilThenAddressBarStringIsEmpty() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertEqual(tabViewModel.addressBarString, "")
    }

    func testWhenURLIsSetThenAddressBarIsUpdated() {
        let urlString = "http://spreadprivacy.com"
        let tabViewModel = TabViewModel.forTabWithURL(.makeURL(from: urlString)!)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.$addressBarString.debounce(for: 0.5, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenURLIsFileURLThenAddressBarIsFilePath() {
        let urlString = "file:///Users/Dax/file.txt"
        let tabViewModel = TabViewModel.forTabWithURL(.makeURL(from: urlString)!)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            XCTAssertEqual(tabViewModel.passiveAddressBarString, urlString)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenURLIsDataURLThenAddressBarIsDataURL() {
        let urlString = "data:,Hello%2C%20World%21"
        let tabViewModel = TabViewModel.forTabWithURL(.makeURL(from: urlString)!)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            XCTAssertEqual(tabViewModel.passiveAddressBarString, "data:")
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - Title

    func testWhenURLIsNilThenTitleIsHome() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertEqual(tabViewModel.title, "Home")
    }

    func testWhenTabTitleIsNotNilThenTitleReflectsTabTitle() {
        let tabViewModel = TabViewModel.forTabWithURL(.duckDuckGo)
        let testTitle = "Test title"
        tabViewModel.tab.title = testTitle

        let titleExpectation = expectation(description: "Title")

        tabViewModel.$title.debounce(for: 0.1, scheduler: RunLoop.main).sink { title in
            XCTAssertEqual(title, testTitle)
            titleExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenTabTitleIsNilThenTitleIsAddressBarString() {
        let tabViewModel = TabViewModel.forTabWithURL(.duckDuckGo)

        let titleExpectation = expectation(description: "Title")

        tabViewModel.$title.debounce(for: 0.1, scheduler: RunLoop.main).sink { title in
            XCTAssertEqual(title, URL.duckDuckGo.host!)
            titleExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - Favicon

    func testWhenContentIsNoneThenFaviconIsNil() {
        let tab = Tab(content: .none)
        let tabViewModel = TabViewModel(tab: tab)

        XCTAssertEqual(tabViewModel.favicon, nil)
    }

    func testWhenContentIsHomeThenFaviconIsHome() {
        let tabViewModel = TabViewModel.aTabViewModel
        tabViewModel.tab.setContent(.homePage)

        let faviconExpectation = expectation(description: "Favicon")
        var fulfilled = false

        tabViewModel.$favicon.debounce(for: 0.1, scheduler: RunLoop.main).sink { favicon in
            guard favicon != nil else { return }
            if favicon == TabViewModel.Favicon.home,
                !fulfilled {
                faviconExpectation.fulfill()
                fulfilled = true
            }
        } .store(in: &cancellables)
        waitForExpectations(timeout: 5, handler: nil)
    }

    // MARK: - Zoom

    func testThatDefaultValueForTabsWebViewIsOne() {
        UserDefaultsWrapper<Any>.clearAll()
        let tabVM = TabViewModel(tab: Tab(), appearancePreferences: AppearancePreferences())

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, DefaultZoomValues.percent100)
    }

    func testWhenAppearancePreferencesZoomLevelIsSetThenTabsWebViewZoomLevelIsUpdated() {
        UserDefaultsWrapper<Any>.clearAll()
        let tabVM = TabViewModel(tab: Tab())
        let randomZoomLevel = DefaultZoomValues.allCases.randomElement()!
        AppearancePreferences.shared.defaultPageZoom = randomZoomLevel

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)
    }

    func testWhenAppearancePreferencesZoomLevelIsSetAndANewTabIsOpenThenItsWebViewHasTheLatestValueOfZoomLevel() {
        UserDefaultsWrapper<Any>.clearAll()
        let randomZoomLevel = DefaultZoomValues.allCases.randomElement()!
        AppearancePreferences.shared.defaultPageZoom = randomZoomLevel

        let tabVM = TabViewModel(tab: Tab(), appearancePreferences: AppearancePreferences())

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)
    }

}

extension TabViewModel {

    static var aTabViewModel: TabViewModel {
        let tab = Tab()
        return TabViewModel(tab: tab)
    }

    static func forTabWithURL(_ url: URL) -> TabViewModel {
        let tab = Tab(content: .url(url))
        return TabViewModel(tab: tab)
    }

}
