//
//  AddressBarTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Carbon
import Combine
import Foundation
import History
import OHHTTPStubs
import OHHTTPStubsSwift
import Suggestions
import XCTest

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class AddressBarTests: XCTestCase {

    var window: MainWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    var isAddressBarFirstResponder: Bool {
        mainViewController.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.isTextFieldEditorFirstResponder
    }

    var addressBarValue: String {
        mainViewController.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.textFieldValue?.string ?? ""
    }

    var addressBarTextField: AddressBarTextField {
        mainViewController.navigationBarViewController.addressBarViewController!.addressBarTextField
    }

    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }

    var webViewConfiguration: WKWebViewConfiguration!
    var schemeHandler: TestSchemeHandler!
    static let testHtml = "<html><head><title>Title</title></head><body>test</body></html>"

    @MainActor
    override func setUp() async throws {
        contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }

        schemeHandler = TestSchemeHandler()
        WKWebView.customHandlerSchemes = [.http, .https]

        webViewConfiguration = WKWebViewConfiguration()
        // ! uncomment this to view navigation logs
        // OSLog.loggingCategories.insert(OSLog.AppCategories.navigation.rawValue)

        // tests return debugDescription instead of localizedDescription
        NSError.disableSwizzledDescription = true

        // mock WebView https protocol handling
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.https.rawValue)

        schemeHandler.middleware = [{ _ in
            return .ok(.html(Self.testHtml))
        }]

        StartupPreferences.shared.customHomePageURL = URL.duckDuckGo.absoluteString
        StartupPreferences.shared.launchToCustomHomePage = false

        WindowControllersManager.shared.pinnedTabsManager.setUp(with: .init())
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    override func tearDown() async throws {
        window?.close()
        window = nil

        webViewConfiguration = nil
        schemeHandler = nil
        WKWebView.customHandlerSchemes = []

        NSError.disableSwizzledDescription = false
        StartupPreferences.shared.launchToCustomHomePage = false

        HTTPStubs.removeAllStubs()
    }

    let asciiToCGEventMap: [String: UInt16] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38, "k": 40,
        "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9,
        "w": 13, "x": 7, "y": 16, "z": 6, "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22,
        "7": 26, "8": 28, "9": 25, "-": 27, ":": UInt16(kVK_ANSI_Semicolon), "\r": 36,
        "/": 44, ".": 47, "\u{1b}": UInt16(kVK_Escape),
    ]

    func type(_ value: String, global: Bool = false) {
        for character in value {
            let str = String(character)
            let code = asciiToCGEventMap[str]!

            let keyDown = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: str, charactersIgnoringModifiers: str, isARepeat: false, keyCode: code)!
            let keyUp = NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: str, charactersIgnoringModifiers: str, isARepeat: false, keyCode: code)!

            if global {
                NSApp.sendEvent(keyDown)
                NSApp.sendEvent(keyUp)
            } else {
                window.sendEvent(keyDown)
                window.sendEvent(keyUp)
            }
        }
    }

    func click(_ view: NSView) {
        let point = view.convert(view.bounds.center, to: nil)
        let mouseDown = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0, windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        let mouseUp = NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: 0, windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!

        window.sendEvent(mouseDown)
        window.sendEvent(mouseUp)
    }

    // MARK: - Tests

    @MainActor
    func testWhenUserStartsTypingOnNewTabPageLoad_userInputIsNotReset() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))

        var isNavigationFinished = false
        var c: AnyCancellable!
        c = tab.webViewDidFinishNavigationPublisher.timeout(5).sink { completion in
            if case .failure(let error) = completion {
                XCTFail("\(error)")
            }
            isNavigationFinished = true
        } receiveValue: { _ in
            isNavigationFinished = true
            c.cancel()
        }

        window = WindowsManager.openNewWindow(with: viewModel)!

        // start typing quickly before the browser window appears;
        // validate when the new tab is displayed, all the entered text is there and not being selected or reset
        var currentCharIdx = Character("a").unicodeScalars.first!.value
        var resultingString = ""
        func typeNext() {
            let str = String(UnicodeScalar(UInt8(currentCharIdx)))
            type(str)
            currentCharIdx += 1
            if currentCharIdx > Character("z").unicodeScalars.first!.value {
                currentCharIdx = Character("a").unicodeScalars.first!.value
            }
            resultingString += str
        }

        while !isNavigationFinished {
            typeNext()
            try await Task.sleep(interval: 0.01)
        }
        withExtendedLifetime(c) {}

        // send some more characters after navigation finishes
        for _ in 0..<5 {
            typeNext()
            try await Task.sleep(interval: 0.01)
        }

        XCTAssertEqual(addressBarValue, resultingString)

    }

    @MainActor
    func testWhenAddressIsTyped_LoadedTopHitSuggestionIsCorrectlyAppendedAndSelected() {
        // top hits should only work for visited urls
        HistoryCoordinator.shared.addVisit(of: URL(string: "https://youtube.com")!)
        let tab = Tab(content: .newtab)
        window = WindowsManager.openNewWindow(with: tab)!

        let json = """
        [
            { "phrase": "youtube.com", "isNav": true },
            { "phrase": "ducks", "isNav": false },
        ]
        """
        let address = "youtube.com"
        stub {
            $0.url!.absoluteString.hasPrefix("https://duckduckgo.com/ac/")
        } response: { _ in
            return HTTPStubsResponse(data: json.utf8data, statusCode: 200, headers: nil)
        }

        // This test reproduces a race condition where the $selectedSuggestionViewModel is published
        // asynchronously on the main queue in response to user input. This can lead to a situation
        // where the user-entered text in the suggestion model is one letter shorter than the actual
        // user input in the address field.
        // As a result, an extra letter may be selected and overtyped, causing a "skipped
        // letter" effect or typographical errors. The goal of this test is to verify that the
        // suggestion model correctly reflects the user's input without any discrepancies.
        // https://app.asana.com/0/1207340338530322/1208166085652339/f
        //
        // Here we simulate receiving the keyboard event right after the suggestion view model received event.
        var index = address.startIndex
        let e = expectation(description: "typing done")
        let c = addressBarTextField.suggestionContainerViewModel!.$selectedSuggestionViewModel
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] suggestion in
                guard suggestion != nil /* suggestion shown */
                        || index == address.startIndex /* address is empty (first iteration) */ else {

                    return
                }
                guard index < address.endIndex else {
                    e.fulfill() // typing done
                    return
                }
                type(String(address[index]))
                index = address.index(after: index)
            }

        waitForExpectations(timeout: 5)
        withExtendedLifetime(c) {}

        XCTAssertEqual("youtube.com", addressBarValue.prefix("youtube.com".count))
    }

    @MainActor
    func testWhenSwitchingBetweenTabs_addressBarFocusStateIsCorrect() async throws {
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [
            Tab(content: .newtab, privacyFeatures: privacyFeaturesMock),
            Tab(content: .settings(pane: .about), privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
            Tab(content: .bookmarks, privacyFeatures: privacyFeaturesMock),
            Tab(content: .newtab, privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
            Tab(content: .newtab, privacyFeatures: privacyFeaturesMock),
            Tab(content: .newtab, privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
        ]))
        AppearancePreferences.shared.showFullURL = true
        window = WindowsManager.openNewWindow(with: viewModel)!

        // Switch between loaded tabs and home tab/settings/bookmarks, validate the Address Bar gets activated on the New Tab; Validate privacy entry button/icon is correct
        for (idx, tab) in viewModel.tabs.enumerated() {
            viewModel.select(tab: tab)
            try await Task.sleep(interval: 0.01)
            if tab.content == .newtab {
                XCTAssertTrue(isAddressBarFirstResponder, "\(idx)")
                XCTAssertEqual(addressBarValue, "", "\(idx)")
            } else {
                XCTAssertFalse(isAddressBarFirstResponder, "\(idx)")
                XCTAssertEqual(addressBarValue, tab.content == .newtab ? "" : tab.content.userEditableUrl!.absoluteString, "\(idx)")
            }
        }
    }

    @MainActor
    func testWhenRestoringToOnboarding_addressBarIsNotActive() async throws {
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .onboardingDeprecated, privacyFeatures: privacyFeaturesMock)]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.transientTabContentViewController!.view)
    }

    @MainActor
    func testWhenRestoringToSettings_addressBarIsNotActive() async throws {
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .settings(pane: .appearance), privacyFeatures: privacyFeaturesMock)]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.preferencesViewController!.view)
    }

    @MainActor
    func testWhenRestoringToBookmarks_addressBarIsNotActive() async throws {
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .bookmarks, privacyFeatures: privacyFeaturesMock)]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.bookmarksViewController!.view)
    }

    @MainActor
    func testWhenRestoringToURL_addressBarIsNotActive() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .loadedByStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenRestoringToNewTab_addressBarIsActive() async throws {
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        XCTAssertTrue(isAddressBarFirstResponder)
    }

    @MainActor
    func testWhenOpeningNewTab_addressBarIsActivated() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .loadedByStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        XCTAssertEqual(window.firstResponder, tab.webView)

        viewModel.append(tab: Tab(content: .newtab, privacyFeatures: privacyFeaturesMock), selected: true)
        try await Task.sleep(interval: 0.01)
        XCTAssertTrue(isAddressBarFirstResponder)

        viewModel.append(tab: Tab(content: .newtab, privacyFeatures: privacyFeaturesMock), selected: true)
        try await Task.sleep(interval: 0.01)
        XCTAssertTrue(isAddressBarFirstResponder)

        viewModel.remove(at: .unpinned(2))
        try await Task.sleep(interval: 0.01)
        XCTAssertTrue(isAddressBarFirstResponder)

        viewModel.remove(at: .unpinned(1))
        try await Task.sleep(interval: 0.01)
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenSwitchingBetweenTabsWithTypedValue_typedValueIsPreserved() async throws {
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [
            Tab(content: .newtab, privacyFeatures: privacyFeaturesMock),
            Tab(content: .settings(pane: .about), privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
            Tab(content: .bookmarks, privacyFeatures: privacyFeaturesMock),
            Tab(content: .newtab, privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
            Tab(content: .newtab, privacyFeatures: privacyFeaturesMock),
            Tab(content: .newtab, privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
        ]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        // Enter something, switch to another tab, enter something, return back, validate the input is preserved, return to tab 2, validate its input is preserved
        for (idx, tab) in viewModel.tabs.enumerated() {
            viewModel.select(tab: tab)
            try await Task.sleep(interval: 0.01)

            if !isAddressBarFirstResponder {
                _=window.makeFirstResponder(addressBarTextField)
            }

            type("tab-\(idx)")
         }
        for (idx, tab) in viewModel.tabs.enumerated() {
            viewModel.select(tab: tab)
            for _ in 0..<10 {
                guard addressBarValue != "tab-\(idx)" else { continue }
                try await Task.sleep(interval: 0.01)
            }
            XCTAssertEqual(addressBarValue, "tab-\(idx)")
            if tab.content == .newtab {
                XCTAssertTrue(isAddressBarFirstResponder, "\(idx)")
            } else {
                XCTAssertFalse(isAddressBarFirstResponder, "\(idx)")
            }
        }
    }

    @MainActor
    func testWhenSwitchingBetweenURLTabs_addressBarIsDeactivated() async throws {
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
            Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock),
        ]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        // open 2 tabs, navigate both somewhere, activate the address bar, switch to another tab - validate the address bar is deactivated
        XCTAssertEqual(window.firstResponder, viewModel.tabs[0].webView)
        _=window.makeFirstResponder(addressBarTextField)

        viewModel.select(at: .unpinned(1))
        try await Task.sleep(interval: 0.01)
        XCTAssertEqual(window.firstResponder, viewModel.tabs[1].webView)

        _=window.makeFirstResponder(addressBarTextField)
        viewModel.select(at: .unpinned(0))
        XCTAssertEqual(window.firstResponder, viewModel.tabs[0].webView)
    }

    @MainActor
    func testWhenDeactivatingAddressBar_webViewShouldBecomeFirstResponder() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        XCTAssertEqual(window.firstResponder, viewModel.tabs[0].webView)
        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)

        type("\u{1b}", global: true) // escape

        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenGoingBack_addressBarIsDeactivated() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .loadedByStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value

        try await tab.setContent(.url(.makeSearchUrl(from: "cats")!, credential: nil, source: .bookmark))?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)

        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)
        try await tab.goBack()?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)

        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)
        try await tab.goForward()?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)

        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)
        try await tab.goBack()?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenGoingBackToNewtabPage_addressBarIsActivated() async throws {
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value
        XCTAssertTrue(isAddressBarFirstResponder)

        try await tab.setContent(.url(.makeSearchUrl(from: "cats")!, credential: nil, source: .bookmark))?.result.get()
        XCTAssertFalse(isAddressBarFirstResponder)

        try await tab.goBack()?.result.get()
        XCTAssertTrue(isAddressBarFirstResponder)

        // text field value shouldn‘t change to a url before it resigns first responder
        var observer: Any? = addressBarTextField.observe(\.stringValue) { addressBarTextField, _ in
            DispatchQueue.main.async {
                if addressBarTextField.isFirstResponder {
                    XCTAssertEqual(addressBarTextField.stringValue, "")
                }
            }
        }

        try await tab.goForward()?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)
        withExtendedLifetime(observer) {}
        observer = nil

        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)
        try await tab.goBack()?.result.get()
        XCTAssertTrue(isAddressBarFirstResponder)

        try await tab.goForward()?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenGoingBackToNewtabPageFromSettings_addressBarIsActivated() async throws {
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value

        try await tab.setContent(.settings(pane: .general))?.result.get()
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.preferencesViewController!.view)

        try await tab.goBack()?.result.get()
        XCTAssertTrue(isAddressBarFirstResponder)

        try await tab.goForward()?.result.get()
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.preferencesViewController!.view)

        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)
        try await tab.goBack()?.result.get()
        XCTAssertTrue(isAddressBarFirstResponder)

        try await tab.goForward()?.result.get()
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.preferencesViewController!.view)
    }

    @MainActor
    func testWhenGoingBackToNewtabPageFromBookmarks_addressBarIsActivated() async throws {
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value

        try await tab.setContent(.bookmarks)?.result.get()
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.bookmarksViewController!.view)

        try await tab.goBack()?.result.get()
        XCTAssertTrue(isAddressBarFirstResponder)

        try await tab.goForward()?.result.get()
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.bookmarksViewController!.view)

        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)
        try await tab.goBack()?.result.get()
        XCTAssertTrue(isAddressBarFirstResponder)

        try await tab.goForward()?.result.get()
        XCTAssertEqual(window.firstResponder, mainViewController.browserTabViewController.bookmarksViewController!.view)
    }

    @MainActor
    func testWhenTabReloaded_addressBarIsDeactivated() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .webViewUpdated), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value
        XCTAssertEqual(window.firstResponder, tab.webView)

        try await tab.setContent(.url(.makeSearchUrl(from: "cats")!, credential: nil, source: .bookmark))?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)

        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)
        try await tab.reload()?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenReloadingFailingPage_addressBarIsDeactivated() async throws {
        // first navigation should fail
        schemeHandler.middleware = [{ _ in
            return .failure(URLError(.notConnectedToInternet))
        }]

        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .webViewUpdated), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value
        XCTAssertEqual(window.firstResponder, tab.webView)

        // activate address bar reload the page
        schemeHandler.middleware = [{ _ in
            return .ok(.html(Self.testHtml))
        }]
        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)
        try await tab.reload()?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenTabReloadedBySubmittingSameAddressAndAddressIsActivated_addressBarIsKeptActiveOnPageLoad() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value
        XCTAssertEqual(window.firstResponder, tab.webView)

        // activate address bar, trigger reload by sending Return key and re-activate the address bar - it should be kept active
        let didFinishNavigation = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        _=window.makeFirstResponder(addressBarTextField)
        type("\r")
        try await Task.sleep(interval: 0.01)
        _=window.makeFirstResponder(addressBarTextField)
        type("some-text")

        try await Task.sleep(interval: 1.0)
        try await didFinishNavigation.value
        XCTAssertTrue(isAddressBarFirstResponder)
        XCTAssertEqual(addressBarValue, "some-text")
    }

    @MainActor
    func testWhenEditingSerpURL_serpIconIsDisplayed() async throws {
        let tab = Tab(content: .url(.makeSearchUrl(from: "catz")!, credential: nil, source: .userEntered("catz")), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value

        _=window.makeFirstResponder(addressBarTextField)
    }

    @MainActor
    func testWhenOpeningBookmark_addressBarIsDeactivated() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .webViewUpdated), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value
        XCTAssertEqual(window.firstResponder, tab.webView)

        _=window.makeFirstResponder(addressBarTextField)
        type("some-text")

        try await tab.setContent(.url(.makeSearchUrl(from: "cats")!, credential: nil, source: .bookmark))?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenOpeningHistoryEntry_addressBarIsDeactivated() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .webViewUpdated), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value
        XCTAssertEqual(window.firstResponder, tab.webView)

        _=window.makeFirstResponder(addressBarTextField)
        type("some-text")

        try await tab.setContent(.url(.makeSearchUrl(from: "cats")!, credential: nil, source: .historyEntry))?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenOpeningURLfromUI_addressBarIsDeactivated() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .webViewUpdated), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value
        XCTAssertEqual(window.firstResponder, tab.webView)

        _=window.makeFirstResponder(addressBarTextField)
        type("some-text")

        try await tab.setContent(.url(.makeSearchUrl(from: "cats")!, credential: nil, source: .ui))?.result.get()
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenHomePageIsOpened_addressBarIsDeactivated() async throws {
        StartupPreferences.shared.launchToCustomHomePage = true

        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .webViewUpdated), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!

        try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value
        XCTAssertEqual(window.firstResponder, tab.webView)
        _=window.makeFirstResponder(addressBarTextField)
        try await Task.sleep(interval: 0.01)

        let didFinishNavigation = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.openHomePage()

        try await didFinishNavigation.value
        XCTAssertEqual(window.firstResponder, tab.webView)
    }

    @MainActor
    func testWhenAddressSubmitted_addressBarIsDeactivated() async throws {
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value

        let didFinishNavigation = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        type(URL.duckDuckGo.absoluteString + "\r")

        try await didFinishNavigation.value
        XCTAssertFalse(isAddressBarFirstResponder)
    }

    @MainActor
    func testWhenAddressSubmittedAndAddressBarIsReactivated_addressBarIsKeptActiveOnPageLoad() async throws {
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value

        let didFinishNavigation = tab.webViewDidFinishNavigationPublisher.timeout(50).first().promise()
        type(URL.duckDuckGo.absoluteString + "\r")

        try await Task.sleep(interval: 0.01)
        _=window.makeFirstResponder(addressBarTextField)
        type("some-text")

        try await Task.sleep(interval: 0.01)
        try await didFinishNavigation.value
        XCTAssertTrue(isAddressBarFirstResponder)
        XCTAssertEqual(addressBarValue, "some-text")
    }

    @MainActor
    func testWhenPageRedirected_addressBarStaysActivePreservingUserInput() async throws {
        let expectation = expectation(description: "request sent")
        schemeHandler.middleware = [{ request in
            if request.url == .duckDuckGo {
                expectation.fulfill()
                return .ok(.html("""
                <html><body>
                <script>
                window.onload = function() {
                    setTimeout(function () {
                        window.location.href = "https://redirected.com";
                    }, 100);
                }
                </script>
                page 1
                </body></html>
                """))
            } else {
                return .ok(.html("""
                <html><body>
                redirected page
                </body></html>
                """))
            }
        }]

        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        XCTAssertEqual(addressBarValue, URL.duckDuckGo.absoluteString)
        let page1loadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        // start typing in the address bar while loading; page is redirected to another page on load - address bar should preserve user input and stay active
        await fulfillment(of: [expectation], timeout: 5)
        _=window.makeFirstResponder(addressBarTextField)
        type("replacement-url")
        _=try await page1loadedPromise.value

        // await for 2nd navigation to finish
        _=try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value

        XCTAssertTrue(isAddressBarFirstResponder)
        XCTAssertEqual(addressBarValue, "replacement-url")
    }

    @MainActor
    func testWhenPageRedirectedWhenAddressBarIsInactive_addressBarShouldReset() async throws {
        AppearancePreferences.shared.showFullURL = true

        let expectation = expectation(description: "request sent")
        schemeHandler.middleware = [{ request in
            if request.url == .duckDuckGo {
                expectation.fulfill()
                return .ok(.html("""
                <html><body>
                <script>
                window.onload = function() {
                    setTimeout(function () {
                        window.location.href = "https://redirected.com/";
                    }, 100);
                }
                </script>
                page 1
                </body></html>
                """))
            } else {
                return .ok(.html("""
                <html><body>
                redirected page
                </body></html>
                """))
            }
        }]

        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        let page1loadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        // start typing in the address bar while loading and deactivate the address bar
        // page is redirected to another page on load - address bar should reset user input
        await fulfillment(of: [expectation], timeout: 5)
        _=window.makeFirstResponder(addressBarTextField)
        type("replacement-url")
        click(tab.webView)
        _=try await page1loadedPromise.value

        // await for 2nd navigation to finish
        _=try await tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise().value

        XCTAssertEqual(window.firstResponder, tab.webView)
        XCTAssertEqual(addressBarValue, "https://redirected.com/")
    }

    @MainActor
    func testWhenActivatingWindowWithPinnedTabOpen_webViewBecomesFirstResponder() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        WindowControllersManager.shared.pinnedTabsManager.setUp(with: TabCollection(tabs: [tab]))

        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)]))
        let tabLoadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        window = WindowsManager.openNewWindow(with: viewModel)!
        viewModel.select(at: .pinned(0))
        _=try await tabLoadedPromise.value

        XCTAssertEqual(window.firstResponder, tab.webView)

        let viewModel2 = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)]))
        let window2 = WindowsManager.openNewWindow(with: viewModel2)!
        defer {
            window2.close()
        }

        // when activaing a Pinned Tab in another window its Web View should become the first responder
        viewModel2.select(at: .pinned(0))
        try await Task.sleep(interval: 0.1)
        XCTAssertEqual(window.firstResponder, window)
        XCTAssertEqual(window2.firstResponder, tab.webView)

        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(interval: 0.1)

        XCTAssertEqual(window.firstResponder, tab.webView)
        XCTAssertEqual(window2.firstResponder, window2)
    }

    @MainActor
    func testWhenActivatingWindowWithPinnedTabWhenAddressBarIsActive_addressBarIsKeptActive() async throws {
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        WindowControllersManager.shared.pinnedTabsManager.setUp(with: TabCollection(tabs: [tab]))

        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)]))
        let tabLoadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        window = WindowsManager.openNewWindow(with: viewModel)!
        viewModel.select(at: .pinned(0))
        _=try await tabLoadedPromise.value

        XCTAssertEqual(window.firstResponder, tab.webView)

        let viewModel2 = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab, privacyFeatures: privacyFeaturesMock)]))
        let window2 = WindowsManager.openNewWindow(with: viewModel2)!
        defer {
            window2.close()
        }

        viewModel2.select(at: .pinned(0))
        try await Task.sleep(interval: 0.01)
        XCTAssertEqual(window.firstResponder, window)
        XCTAssertEqual(window2.firstResponder, tab.webView)

        // when activaing a Pinned Tab in another window when its Address Bar is active, it should be kept active
        _=window.makeFirstResponder(addressBarTextField)
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(interval: 0.01)

        XCTAssertTrue(isAddressBarFirstResponder)
        XCTAssertEqual(window2.firstResponder, window2)
    }

    @MainActor
    func test_WhenSiteCertificateNil_ThenAddressBarShowsStandardShieldIcon() async throws {
        // GIVEN
        let expectedImage = NSImage(named: "Shield")!
        let evaluator = MockCertificateEvaluator()
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration, certificateTrustEvaluator: evaluator)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        let tabLoadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        // WHEN
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tabLoadedPromise.value

        // THEN
        let shieldImage = mainViewController.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.privacyEntryPointButton.image!
        XCTAssertTrue(shieldImage.isEqualToImage(expectedImage))
    }

    @MainActor
    func test_WhenSiteCertificateValid_ThenAddressBarShowsStandardShieldIcon() async throws {
        // GIVEN
        let expectedImage = NSImage(named: "Shield")!
        let evaluator = MockCertificateEvaluator()
        evaluator.isValidCertificate = true
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration, certificateTrustEvaluator: evaluator)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        let tabLoadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        // WHEN
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tabLoadedPromise.value

        // THEN
        let shieldImage = mainViewController.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.privacyEntryPointButton.image!
        XCTAssertTrue(shieldImage.isEqualToImage(expectedImage))
    }

    @MainActor
    func test_WhenSiteCertificateInvalid_ThenAddressBarShowsDottedShieldIcon() async throws {
        // GIVEN
        let expectedImage = NSImage(named: "ShieldDot")!
        let evaluator = MockCertificateEvaluator()
        evaluator.isValidCertificate = false
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration, certificateTrustEvaluator: evaluator)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        let tabLoadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        // WHEN
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tabLoadedPromise.value

        // THEN
        let shieldImage = mainViewController.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.privacyEntryPointButton.image!
        XCTAssertTrue(shieldImage.isEqualToImage(expectedImage))
    }

    @MainActor
    func test_ZoomLevelNonDefault_ThenZoomButtonIsVisible() async throws {
        // GIVEN
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        viewModel.selectedTabViewModel?.zoomWasSet(to: .percent150)
        let tabLoadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        // WHEN
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tabLoadedPromise.value

        // THEN
        let zoomButton = mainViewController.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.zoomButton!
        XCTAssertFalse(zoomButton.isHidden)
    }

    @MainActor
    func test_ZoomLevelDefault_ThenZoomButtonIsNotVisible() async throws {
        // GIVEN
        let tab = Tab(content: .url(.duckDuckGo, credential: nil, source: .userEntered("")), webViewConfiguration: webViewConfiguration)
        tab.webView.zoomLevel = AccessibilityPreferences.shared.defaultPageZoom
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        viewModel.selectedTabViewModel?.zoomWasSet(to: .percent100)
        let tabLoadedPromise = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        // WHEN
        window = WindowsManager.openNewWindow(with: viewModel)!
        _=try await tabLoadedPromise.value

        // THEN
        let zoomButton = mainViewController.navigationBarViewController.addressBarViewController!.addressBarButtonsViewController!.zoomButton!
        XCTAssertTrue(zoomButton.isHidden)
    }

    @MainActor
    func test_WhenControlTextDidChange_ThenreporterTrackAddressBarTypedInCalled() async throws {
        // GIVEN
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .newtab)]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        let textField = mainViewController.navigationBarViewController.addressBarViewController?.addressBarTextField
        XCTAssertNotNil(textField?.onboardingDelegate)
        let reporter = CapturingOnboardingAddressBarReporting()
        textField?.onboardingDelegate = reporter

        // WHEN
        textField?.controlTextDidChange(.init(name: .PasswordManagerChanged))

        // THEN
        XCTAssertTrue(reporter.trackAddressBarTypedInCalled)
    }
}

protocol MainActorPerformer {
    func perform(_ closure: @MainActor () -> Void)
}
struct OnMainActor: MainActorPerformer {
    private init() {}

    static func instance() -> MainActorPerformer { OnMainActor() }

    @MainActor(unsafe)
    func perform(_ closure: @MainActor () -> Void) {
        closure()
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }

    func isEqualToImage(_ image: NSImage) -> Bool {
        guard let data1 = self.pngData(),
              let data2 = image.pngData() else {
            return false
        }
        return data1 == data2
    }
}

class MockCertificateEvaluator: CertificateTrustEvaluating {
    var isValidCertificate: Bool?

    func evaluateCertificateTrust(trust: SecTrust?) -> Bool? {
        return isValidCertificate
    }
}

class CapturingOnboardingAddressBarReporting: OnboardingAddressBarReporting {
    var trackAddressBarTypedInCalled = false

    func trackAddressBarTypedIn() {
        trackAddressBarTypedInCalled = true
    }

    func trackPrivacyDashboardOpened() {
    }

    func trackSiteVisited() {
    }
}
