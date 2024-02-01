//
//  ErrorPageTests.swift
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

import Combine
import Common
import XCTest
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
@MainActor
class ErrorPageTests: XCTestCase {

    var window: NSWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    var webViewConfiguration: WKWebViewConfiguration!
    var schemeHandler: TestSchemeHandler!

    static let emptyHtml = "<html><body /></html>"

    @MainActor
    override func setUp() async throws {
        schemeHandler = TestSchemeHandler()
        WKWebView.customHandlerSchemes = [.http, .https]

        webViewConfiguration = WKWebViewConfiguration()
        // ! uncomment this to view navigation logs
        // OSLog.loggingCategories.insert(OSLog.AppCategories.navigation.rawValue)

        // tests return debugDescription instead of localizedDescription
        NSError.disableSwizzledDescription = true

        // mock WebView https protocol handling
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.https.rawValue)
    }

    @MainActor
    override func tearDown() async throws {
        window?.close()
        window = nil

        webViewConfiguration = nil
        schemeHandler = nil
        WKWebView.customHandlerSchemes = []

        NSError.disableSwizzledDescription = false
    }

    func testWhenPageFailsToLoad_errorPageShown() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration)
        window = WindowsManager.openNewWindow(with: tab)!
        let eNewtabPageLoaded = tab.newtabPagePublisher
            .timeout(5)
            .first()
            .promise()
        try await eNewtabPageLoaded.value

        // navigate to DDG, fail with error
        schemeHandler.middleware = [{ _ in .failure(NSError.hostNotFound) }]
        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))

        let eNavigationFailed = tab.$error
            .compactMap { $0 }
            .timeout(5)
            .first()
            .promise()

        let error = try await eNavigationFailed.value

        XCTAssertEqual(error.errorCode, NSError.hostNotFound.code)
        XCTAssertEqual(error.localizedDescription, NSError.hostNotFound.localizedDescription)
        let titleText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByTagName('title')[0].innerText")
        let headerText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")

        XCTAssertEqual(tab.title, UserText.tabErrorTitle)
        XCTAssertEqual(titleText?.trimmingWhitespace(), tab.title)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.hostNotFound.localizedDescription)
        XCTAssertTrue(tab.canGoBack)
        XCTAssertFalse(tab.canGoForward)
        XCTAssertEqual(tab.backHistoryItems.count, 1)
        XCTAssertEqual(tab.backHistoryItems.first?.url, .newtab)
        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertEqual(tab.content.userEditableUrl, .test)
    }

    func testWhenTabWithNoConnectionErrorActivated_reloadTriggered() async throws {
        // open 2 Tabs with newtab page
        let tab1 = Tab(content: .newtab, webViewConfiguration: webViewConfiguration)
        let tab2 = Tab(content: .newtab, webViewConfiguration: webViewConfiguration)
        let tabsViewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab1, tab2]))
        window = WindowsManager.openNewWindow(with: tabsViewModel)!

        // wait until Home page loads
        let eNewtabPageLoaded = tab1.newtabPagePublisher
            .timeout(5)
            .first()
            .promise()
        try await eNewtabPageLoaded.value

        // navigate to a failing url
        schemeHandler.middleware = [{ _ in .failure(NSError.noConnection) }]
        tab1.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        // wait for error page to open
        let eNavigationFailed = tab1.$error
            .compactMap { $0 }
            .timeout(10)
            .first()
            .promise()

        _=try await eNavigationFailed.value

        // switch to tab 2
        tabsViewModel.select(at: .unpinned(1))

        // next load should be ok
        let eServerQueried = expectation(description: "server request sent")
        schemeHandler.middleware = [{ _ in
            eServerQueried.fulfill()
            return .ok(.html(Self.emptyHtml))
        }]
        // coming back to the failing tab 1 should trigger its reload
        let eNavigationSucceeded = tab1.urlPublisher
            .timeout(10)
            .first()
            .promise()

        tabsViewModel.select(at: .unpinned(0))

        let url = try await eNavigationSucceeded.value
        await fulfillment(of: [eServerQueried], timeout: 1)
        XCTAssertEqual(url, .test)
        XCTAssertNil(tab1.error)
    }

    func testWhenTabWithConnectionLostErrorActivatedAndReloadFailsAgain_errorPageIsShownOnce() async throws {
        // open 2 Tabs with newtab page
        // navigate to a failing url right away
        schemeHandler.middleware = [{ _ in
            .failure(NSError.connectionLost)
        }]
        let tab1 = Tab(content: .url(.test, source: .link), webViewConfiguration: webViewConfiguration)
        let tab2 = Tab(content: .newtab, webViewConfiguration: webViewConfiguration)
        let tabsViewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab1, tab2]))
        window = WindowsManager.openNewWindow(with: tabsViewModel)!

        // wait for error page to open
        let eNavigationFailed = tab1.$error
            .compactMap { $0 }
            .timeout(10)
            .first()
            .promise()

        _=try await eNavigationFailed.value

        // switch to tab 2
        tabsViewModel.select(at: .unpinned(1))

        // coming back to the failing tab 1 should trigger its reload but it will fail again
        let eServerQueried = expectation(description: "server request sent")
        schemeHandler.middleware = [{ _ in
            eServerQueried.fulfill()
            return .failure(NSError.noConnection)
        }]
        let eNavigationFailed2 = tab1.$error
            .compactMap { $0 }
            .filter { $0.errorCode == NSError.noConnection.code }
            .timeout(5)
            .first()
            .promise()

        tabsViewModel.select(at: .unpinned(0))

        await fulfillment(of: [eServerQueried], timeout: 1)
        let error = try await eNavigationFailed2.value

        let c = tab2.$isLoading.dropFirst().sink { isLoading in
            XCTFail("Failing tab shouldn‘t reload again (isLoading: \(isLoading))")
        }

        XCTAssertEqual(error.errorCode, NSError.noConnection.code)
        XCTAssertEqual(error.localizedDescription, NSError.noConnection.localizedDescription)
        let titleText: String? = try await tab1.webView.evaluateJavaScript("document.getElementsByTagName('title')[0].innerText")
        let headerText: String? = try await tab1.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab1.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")
        XCTAssertEqual(tab1.title, UserText.tabErrorTitle)
        XCTAssertEqual(titleText?.trimmingWhitespace(), tab1.title)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.noConnection.localizedDescription)

        try await Task.sleep(interval: 0.4) // sleep a little to confirm no more navigations are performed
        withExtendedLifetime(c) {}
    }

    func testWhenTabWithOtherErrorActivated_reloadNotTriggered() {

    }

    func testWhenErrorPageRestored_reloadTriggered() {

    }

    func testWhenGoingBackToSessionRestoredErrorPage_reloadTriggered() {

    }

    func testWhenDDGloadingFailsAfterSessionRestoration_navigationHistoryIsPreserved() {

    }

    func testPinnedTabDoesNotNavigateAway() {

    }
}

private extension URL {
    static let test = URL(string: "https://test.com/")!
}

extension Tab {

    func contentLoadingPublisher(filter: @escaping ((old: (Tab.TabContent, isLoading: Bool), new: (Tab.TabContent, isLoading: Bool))) -> Bool) -> AnyPublisher<TabContent, Never> {
        $content.combineLatest($isLoading)
            .scan((old: (Tab.TabContent.none, isLoading: false), new: (Tab.TabContent.none, isLoading: false))) {
                (old: $0.new, new: $1)
            }
            .filter(filter)
            .map { $0.new.0 }
            .eraseToAnyPublisher()
    }

    var urlPublisher: AnyPublisher<URL, Never> {
        contentLoadingPublisher { (old, new) in
            (old.0.isUrl && old.isLoading && new.0.isUrl && !new.isLoading && old.0.url == new.0.url) // .url loading -> .url loaded
        }
        .compactMap { $0.url }
        .eraseToAnyPublisher()
    }

    var newtabPagePublisher: AnyPublisher<Void, Never> {
        contentLoadingPublisher { (old, new) in
            (old.0 == .newtab && old.isLoading && new.0 == .newtab && !new.isLoading) // .newtab loading -> .newtab loaded
        }.asVoid().eraseToAnyPublisher()
    }

}

private extension NSError {

    static let hostNotFound: NSError = {
        let errorCode = -1003
        let errorDescription = "hostname not found"
        let wkError = NSError(domain: NSURLErrorDomain, code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])
        return wkError
    }()

    static let noConnection: NSError = {
        let errorDescription = "no internet connection"
        return URLError(.notConnectedToInternet, userInfo: [NSLocalizedDescriptionKey: errorDescription]) as NSError
    }()

    static let connectionLost: NSError = {
        let errorDescription = "connection lost"
        return URLError(.networkConnectionLost, userInfo: [NSLocalizedDescriptionKey: errorDescription]) as NSError
    }()

}
