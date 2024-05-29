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

import Combine
import Navigation
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class TabViewModelTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    // MARK: - Can reload

    @MainActor
    func testWhenURLIsNilThenCanReloadIsFalse() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertFalse(tabViewModel.canReload)
    }

    @MainActor
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

    @MainActor
    func testWhenURLIsNilThenAddressBarStringIsEmpty() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertEqual(tabViewModel.addressBarString, "")
    }

    @MainActor
    func testWhenURLIsSetThenAddressBarIsUpdated() {
        let urlString = "http://spreadprivacy.com"
        let url = URL.makeURL(from: urlString)!
        let tabViewModel = TabViewModel.forTabWithURL(url)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.simulateLoadingCompletion(url, in: tabViewModel.tab.webView)

        tabViewModel.$addressBarString.debounce(for: 0.5, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    @MainActor
    func testWhenURLIsFileURLAndShowFullUrlIsDisabledThenAddressBarIsFileName() {
        let urlString = "file:///Users/Dax/file.txt"
        let url = URL.makeURL(from: urlString)!
        let tab = Tab(content: .url(url, source: .link))
        let appearancePreferences = AppearancePreferences(persistor: AppearancePreferencesPersistorMock(showFullURL: false))
        let tabViewModel = TabViewModel(tab: tab, appearancePreferences: appearancePreferences)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.simulateLoadingCompletion(url, in: tabViewModel.tab.webView)

        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            XCTAssertEqual(tabViewModel.passiveAddressBarAttributedString.string, url.lastPathComponent)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    @MainActor
    func testWhenURLIsFileURLAndShowFullUrlIsEnabledThenAddressBarIsFilePath() {
        let urlString = "file:///Users/Dax/file.txt"
        let url = URL.makeURL(from: urlString)!
        let tab = Tab(content: .url(url, source: .link))
        let appearancePreferences = AppearancePreferences(persistor: AppearancePreferencesPersistorMock(showFullURL: true))
        let tabViewModel = TabViewModel(tab: tab, appearancePreferences: appearancePreferences)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.simulateLoadingCompletion(url, in: tabViewModel.tab.webView)

        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            XCTAssertEqual(tabViewModel.passiveAddressBarAttributedString.string, urlString)
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    @MainActor
    func testWhenURLIsDataURLThenAddressBarIsDataURL() {
        let urlString = "data:,Hello%2C%20World%21"
        let url = URL.makeURL(from: urlString)!
        let tabViewModel = TabViewModel.forTabWithURL(url)

        let addressBarStringExpectation = expectation(description: "Address bar string")

        tabViewModel.simulateLoadingCompletion(url, in: tabViewModel.tab.webView)

        tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssertEqual(tabViewModel.addressBarString, urlString)
            XCTAssertEqual(tabViewModel.passiveAddressBarAttributedString.string, "data:")
            addressBarStringExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    @MainActor
    func testWhenURLIsBlobURLWithBasicAuthThenAddressBarStripsBasicAuth() {
        let urlStrings = ["blob:https://spoofed.domain.com%20%20%20%20%20%20%20%20%20@attacker.com",
                          "blob:ftp://another.spoofed.domain.com%20%20%20%20%20%20%20%20%20@attacker.com",
                          "blob:http://yetanother.spoofed.domain.com%20%20%20%20%20%20%20%20%20@attacker.com"]
        let expectedStarts = ["blob:https://", "blob:ftp://", "blob:http://"]
        let expectedNotContains = ["spoofed.domain.com", "another.spoofed.domain.com", "yetanother.spoofed.domain.com"]
        let uuidPattern = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        let uuidRegex = try! NSRegularExpression(pattern: uuidPattern, options: [])

        for i in 0..<urlStrings.count {
            let url = URL.makeURL(from: urlStrings[i])!
            let tabViewModel = TabViewModel.forTabWithURL(url)
            let addressBarStringExpectation = expectation(description: "Address bar string")
            tabViewModel.simulateLoadingCompletion(url, in: tabViewModel.tab.webView)

            tabViewModel.$addressBarString.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
                XCTAssertTrue(tabViewModel.addressBarString.starts(with: expectedStarts[i]))
                XCTAssertTrue(tabViewModel.addressBarString.contains("attacker.com"))
                XCTAssertFalse(tabViewModel.addressBarString.contains(expectedNotContains[i]))
                let range = NSRange(location: 0, length: tabViewModel.addressBarString.utf16.count)
                let match = uuidRegex.firstMatch(in: tabViewModel.addressBarString, options: [], range: range)
                XCTAssertNotNil(match, "URL does not end with a GUID")
                addressBarStringExpectation.fulfill()
            } .store(in: &cancellables)
            waitForExpectations(timeout: 1, handler: nil)
        }
    }

    // MARK: - Title

    @MainActor
    func testWhenURLIsNilThenTitleIsNewTab() {
        let tabViewModel = TabViewModel.aTabViewModel

        XCTAssertEqual(tabViewModel.title, UserText.tabHomeTitle)
    }

    @MainActor
    func testWhenTabTitleIsNotNilThenTitleReflectsTabTitle() async throws {
        let tabViewModel = TabViewModel.forTabWithURL(.duckDuckGo)
        let testTitle = "Test title"

        let titleExpectation = expectation(description: "Title")
        tabViewModel.$title.dropFirst().sink {
            if case .failure(let error) = $0 {
                XCTFail("\(error)")
            }
        } receiveValue: { title in
            XCTAssertEqual(title, testTitle)
            titleExpectation.fulfill()
        } .store(in: &cancellables)

        tabViewModel.tab.title = testTitle

        await fulfillment(of: [titleExpectation], timeout: 0.5)
    }

    @MainActor
    func testWhenTabTitleIsNilThenTitleIsAddressBarString() {
        let tabViewModel = TabViewModel.forTabWithURL(.duckDuckGo)

        let titleExpectation = expectation(description: "Title")

        tabViewModel.$title.debounce(for: 0.01, scheduler: RunLoop.main).sink { title in
            XCTAssertEqual(title, URL.duckDuckGo.host!)
            titleExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    // MARK: - Favicon

    @MainActor
    func testWhenContentIsNoneThenFaviconIsNil() {
        let tab = Tab(content: .none)
        let tabViewModel = TabViewModel(tab: tab)

        XCTAssertEqual(tabViewModel.favicon, nil)
    }

    @MainActor
    func testWhenContentIsHomeThenFaviconIsHome() {
        let tabViewModel = TabViewModel.aTabViewModel
        tabViewModel.tab.setContent(.newtab)

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

    @MainActor
    func testThatDefaultValueForTabsWebViewIsOne() {
        UserDefaultsWrapper<Any>.clearAll()
        let tabVM = TabViewModel(tab: Tab(), appearancePreferences: AppearancePreferences(), accessibilityPreferences: AccessibilityPreferences())

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, DefaultZoomValue.percent100)
    }

    @MainActor
    func testWhenPreferencesDefaultZoomLevelIsSetThenTabsWebViewZoomLevelIsUpdated() {
        UserDefaultsWrapper<Any>.clearAll()
        let tabVM = TabViewModel(tab: Tab())
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!
        AccessibilityPreferences.shared.defaultPageZoom = randomZoomLevel

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)
    }

    @MainActor
    func testWhenPreferencesDefaultZoomLevelIsSetAndANewTabIsOpenThenItsWebViewHasTheLatestValueOfZoomLevel() {
        UserDefaultsWrapper<Any>.clearAll()
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!
        AccessibilityPreferences.shared.defaultPageZoom = randomZoomLevel

        let tabVM = TabViewModel(tab: Tab(), appearancePreferences: AppearancePreferences())

        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)
    }

    @MainActor
    func test_WhenPreferencesDefaultZoomLevelIsSet_AndThereIsAZoomLevelForWebsite_ThenTabsWebViewZoomLevelIsNotUpdated() {
        // GIVEN
        UserDefaultsWrapper<Any>.clearAll()
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)
        var tab = Tab(url: url)
        var tabVM = TabViewModel(tab: tab)

        // WHEN
        AccessibilityPreferences.shared.defaultPageZoom = .percent50
        tab = Tab(url: url)
        tabVM = TabViewModel(tab: tab)

        // THEN
        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)
    }

    @MainActor
    func test_WhenPreferencesDefaultZoomLevelIsSet_AndThereIsAZoomLevelForWebsite_AndIsFireWindow_ThenTabsWebViewZoomLevelIsNotUpdated() {
        // GIVEN
        UserDefaultsWrapper<Any>.clearAll()
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)
        let tab = Tab(url: url)
        var tabVM = TabViewModel(tab: tab)

        // WHEN
        AccessibilityPreferences.shared.defaultPageZoom = .percent50
        let burnerTab = Tab(content: .url(url, credential: nil, source: .ui), burnerMode: BurnerMode(isBurner: true))
        tabVM = TabViewModel(tab: burnerTab)

        // THEN
        XCTAssertEqual(tabVM.tab.webView.zoomLevel, AccessibilityPreferences.shared.defaultPageZoom)
    }

    @MainActor
    func test_WhenPreferencesZoomPerWebsiteLevelIsSet_AndANewTabIsOpen_ThenItsWebViewHasTheLatestValueOfZoomLevel() {
        // GIVEN
        UserDefaultsWrapper<Any>.clearAll()
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)

        // WHEN
        let tab = Tab(url: url)
        let tabVM = TabViewModel(tab: tab, appearancePreferences: AppearancePreferences())

        // THEN
        XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel)
    }

    @MainActor
    func test_WhenPreferencesZoomPerWebsiteLevelIsSet_AndANewBurnerTabIsOpen_ThenItsWebViewHasTheDefaultZoomLevel() {
        // GIVEN
        UserDefaultsWrapper<Any>.clearAll()
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)

        // WHEN
        let burnerTab = Tab(content: .url(url, credential: nil, source: .ui), burnerMode: BurnerMode(isBurner: true))
        let tabVM = TabViewModel(tab: burnerTab, appearancePreferences: AppearancePreferences())

        // THEN
        XCTAssertEqual(tabVM.tab.webView.zoomLevel, AccessibilityPreferences.shared.defaultPageZoom)
    }

    @MainActor
    func test_WhenPreferencesZoomPerWebsiteLevelIsSet_ThenTabsWebViewZoomLevelIsUpdated() async {
        // GIVEN
        UserDefaultsWrapper<Any>.clearAll()
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        let tab = Tab(url: url)
        let tabVM = TabViewModel(tab: tab)
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!

        // WHEN
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)

        // THEN
        await MainActor.run {
            XCTAssertEqual(tabVM.tab.webView.zoomLevel, randomZoomLevel, "Tab's web view zoom level was not updated as expected.")
        }
    }

    @MainActor
    func test_WhenPreferencesZoomPerWebsiteLevelIsSet_AndIsFireWindow_ThenTabsWebViewZoomLevelIsNot() async {
        // GIVEN
        UserDefaultsWrapper<Any>.clearAll()
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        let burnerTab = Tab(content: .url(url, credential: nil, source: .ui), burnerMode: BurnerMode(isBurner: true))
        let tabVM = TabViewModel(tab: burnerTab)
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!

        // WHEN
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)

        // THEN
        await MainActor.run {
            XCTAssertEqual(tabVM.tab.webView.zoomLevel, AccessibilityPreferences.shared.defaultPageZoom)
        }
    }

    @MainActor
    func test_WhenZoomWasSetIsCalled_ThenAppearancePreferencesPerWebsiteZoomIsSet() {
        // GIVEN
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        UserDefaultsWrapper<Any>.clearAll()
        let tab = Tab(url: url)
        let tabVM = TabViewModel(tab: tab)
        let filteredCases = DefaultZoomValue.allCases.filter { $0 !=  AccessibilityPreferences.shared.defaultPageZoom}
        let randomZoomLevel = filteredCases.randomElement()!

        // WHEN
        tabVM.zoomWasSet(to: randomZoomLevel)

        // THEN
        XCTAssertEqual(AccessibilityPreferences.shared.zoomPerWebsite(url: hostURL), randomZoomLevel)
    }

    @MainActor
    func test_WhenZoomWasSetIsCalled_AndIsFireWindow_ThenAppearancePreferencesPerWebsiteZoomIsNotSet() {
        // GIVEN
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: AccessibilityPreferences.shared.defaultPageZoom, url: hostURL)
        UserDefaultsWrapper<Any>.clearAll()
        let burnerTab = Tab(content: .url(url, credential: nil, source: .ui), burnerMode: BurnerMode(isBurner: true))
        let tabVM = TabViewModel(tab: burnerTab)
        let filteredCases = DefaultZoomValue.allCases.filter { $0 !=  AccessibilityPreferences.shared.defaultPageZoom}
        let randomZoomLevel = filteredCases.randomElement()!

        // WHEN
        print(randomZoomLevel)
        tabVM.zoomWasSet(to: randomZoomLevel)

        // THEN
        XCTAssertEqual(AccessibilityPreferences.shared.zoomPerWebsite(url: hostURL), nil)
    }

    @MainActor
    func test_WhenWebViewResetZoomLevelForASite_ThenNoZoomSavedForTheSite() {
        // GIVEN
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        UserDefaultsWrapper<Any>.clearAll()
        let filteredCases = DefaultZoomValue.allCases.filter { $0 != AccessibilityPreferences.shared.defaultPageZoom }
        let randomZoomLevel = filteredCases.randomElement()!
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)
        let tab = Tab(url: url)
        let tabView = TabViewModel(tab: tab)

        // WHEN
        tabView.tab.webView.resetZoomLevel()

        // THEN
        XCTAssertEqual(AccessibilityPreferences.shared.zoomPerWebsite(url: hostURL), nil)
    }

    @MainActor
    func test_WhenWebViewZoomInForASite_ThenNewZoomSavedForTheSite() async {
        // GIVEN
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        UserDefaultsWrapper<Any>.clearAll()
        let (randomZoomLevel, nextZoomLevel, _) = randomLevelAndAdjacent()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)
        let tab = Tab(url: url)
        window.contentView?.addSubview(tab.webView)
        tab.webView.frame = window.contentView!.bounds
        window.makeKeyAndOrderFront(nil)
        let tabView = TabViewModel(tab: tab)

        // WHEN
        tabView.tab.webView.zoomIn()

        // THEN
        if nextZoomLevel == AccessibilityPreferences.shared.defaultPageZoom {
            XCTAssertNil(AccessibilityPreferences.shared.zoomPerWebsite(url: hostURL))
        } else {
            XCTAssertEqual(AccessibilityPreferences.shared.zoomPerWebsite(url: hostURL), nextZoomLevel)
        }
    }

    @MainActor
    func test_WhenWebViewZoomOutForASite_ThenNewZoomSavedForTheSite() async {
        // GIVEN
        let url = URL(string: "https://app.asana.com/0/1")!
        let hostURL = "https://app.asana.com/"
        UserDefaultsWrapper<Any>.clearAll()
        let (randomZoomLevel, _, previousZoomLevel) = randomLevelAndAdjacent()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        AccessibilityPreferences.shared.updateZoomPerWebsite(zoomLevel: randomZoomLevel, url: hostURL)
        let tab = Tab(url: url)
        window.contentView?.addSubview(tab.webView)
        tab.webView.frame = window.contentView!.bounds
        window.makeKeyAndOrderFront(nil)
        let tabView = TabViewModel(tab: tab)

        // WHEN
        tabView.tab.webView.zoomOut()

        // THEN
        if previousZoomLevel == AccessibilityPreferences.shared.defaultPageZoom {
            XCTAssertNil(AccessibilityPreferences.shared.zoomPerWebsite(url: hostURL))
        } else {
            XCTAssertEqual(AccessibilityPreferences.shared.zoomPerWebsite(url: hostURL), previousZoomLevel)
        }
    }

    private func randomLevelAndAdjacent() -> (randomLevel: DefaultZoomValue, nextLevel: DefaultZoomValue, previousLevel: DefaultZoomValue) {
        let allCases = DefaultZoomValue.allCases

        let selectableRange = 1..<(allCases.count - 1)
        let randomIndex = selectableRange.randomElement()!
        let randomLevel = allCases[randomIndex]

        let nextLevel = allCases[randomIndex + 1]
        let previousLevel = allCases[randomIndex - 1]

        return (randomLevel, nextLevel, previousLevel)
    }
}

extension TabViewModel {

    @MainActor
    static var aTabViewModel: TabViewModel {
        let tab = Tab()
        return TabViewModel(tab: tab)
    }

    @MainActor
    static func forTabWithURL(_ url: URL) -> TabViewModel {
        let tab = Tab(content: .url(url, source: .link))
        return TabViewModel(tab: tab)
    }

    @MainActor
    func simulateLoadingCompletion(_ url: URL, in webView: WKWebView) {
        let navAction = NavigationAction(request: URLRequest(url: url), navigationType: .other, currentHistoryItemIdentity: nil, redirectHistory: nil, isUserInitiated: nil, sourceFrame: .mainFrame(for: webView), targetFrame: .mainFrame(for: webView), shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: .init(nil), responders: .init(), state: .started, redirectHistory: [navAction], isCurrent: true, isCommitted: true)
        self.tab.didCommit(navigation)
    }

}
