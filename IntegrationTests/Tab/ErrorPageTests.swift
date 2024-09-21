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
class ErrorPageTests: XCTestCase {

    var window: NSWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }

    var webViewConfiguration: WKWebViewConfiguration!
    var schemeHandler: TestSchemeHandler!

    static let pageTitle = "test page"
    static let testHtml = "<html><head><title>\(pageTitle)</title></head><body>test</body></html>"
    static let alternativeTitle = "alternative page"
    static let alternativeHtml = "<html><head><title>\(alternativeTitle)</title></head><body>alternative body</body></html>"

    static let sessionStateData = Data.sessionRestorationMagic + """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    <key>IsAppInitiated</key>
    <true/>
    <key>SessionHistory</key>
    <dict>
        <key>SessionHistoryVersion</key>
        <integer>1</integer>
        <key>SessionHistoryEntries</key>
        <array>
            <dict>
                <key>SessionHistoryEntryOriginalURL</key>
                <string>\(URL.newtab.absoluteString)</string>
                <key>SessionHistoryEntryTitle</key>
                <string></string>
                <key>SessionHistoryEntryShouldOpenExternalURLsPolicyKey</key>
                <integer>1</integer>
                <key>SessionHistoryEntryData</key>
                <data>AAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAEGPVpVAQBgAAAAAAAAAAAP////8AAAAAD2PVpVAQBgD/////AAAAAAAAAAAAAIA/AAAAAP////8=</data>
                <key>SessionHistoryEntryURL</key>
                <string>\(URL.newtab.absoluteString)</string>
            </dict>
            <dict>
                <key>SessionHistoryEntryOriginalURL</key>
                <string>\(URL.test.absoluteString)</string>
                <key>SessionHistoryEntryTitle</key>
                <string>test page</string>
                <key>SessionHistoryEntryShouldOpenExternalURLsPolicyKey</key>
                <integer>1</integer>
                <key>SessionHistoryEntryData</key>
                <data>AAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAwvZLp1AQBgAAAAAAAAAAAP////8AAAAAwfZLp1AQBgD/////AAAAAAAAAAAAAIA/AAAAAP////8=</data>
                <key>SessionHistoryEntryURL</key>
                <string>\(URL.test.absoluteString)</string>
            </dict>
            <dict>
                <key>SessionHistoryEntryOriginalURL</key>
                <string>\(URL.alternative.absoluteString)</string>
                <key>SessionHistoryEntryTitle</key>
                <string>alternative page</string>
                <key>SessionHistoryEntryShouldOpenExternalURLsPolicyKey</key>
                <integer>1</integer>
                <key>SessionHistoryEntryData</key>
                <data>AAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAeWCYp1AQBgAAAAAAAAAAAP////8AAAAAeGCYp1AQBgD/////AAAAAAAAAAAAAAAAAAAAAP////8=</data>
                <key>SessionHistoryEntryURL</key>
                <string>\(URL.alternative.absoluteString)</string>
            </dict>
        </array>
        <key>SessionHistoryCurrentIndex</key>
        <integer>1</integer>
    </dict>
    <key>RenderTreeSize</key>
    <integer>4</integer>
    </dict>
    </plist>
    """.utf8data

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

    // MARK: - Tests

    @MainActor
    func testWhenPageFailsToLoad_errorPageShown() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await eNewtabPageLoaded.value

        // navigate to test url, fail with error
        schemeHandler.middleware = [{ _ in
            .failure(NSError.hostNotFound)
        }]

        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        let error = try await eNavigationFailed.value
        _=try await eNavigationFinished.value

        XCTAssertEqual(error.errorCode, NSError.hostNotFound.code)
        XCTAssertEqual(error.localizedDescription, NSError.hostNotFound.localizedDescription)
        let headerText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")

        XCTAssertNil(tab.title)
        XCTAssertEqual(tabViewModel.title, UserText.tabErrorTitle)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.hostNotFound.localizedDescription)
        XCTAssertTrue(tab.canGoBack)
        XCTAssertFalse(tab.canGoForward)
        XCTAssertTrue(tab.canReload)
        XCTAssertFalse(viewModel.tabViewModel(at: 0)!.canSaveContent)
        XCTAssertEqual(tab.backHistoryItems.count, 1)
        XCTAssertEqual(tab.backHistoryItems.first?.url, .newtab)
        XCTAssertNil(tab.currentHistoryItem?.title)
        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertEqual(tab.content.userEditableUrl, .test)
    }

    @MainActor
    func testWhenTabWithNoConnectionErrorActivated_reloadTriggered() async throws {
        // open 2 Tabs with newtab page
        let tab1 = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let tab2 = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNewtabPageLoaded = tab1.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let eNewtab2PageLoaded = tab1.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let tabsViewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab1, tab2]))
        tabsViewModel.select(at: .unpinned(0))
        window = WindowsManager.openNewWindow(with: tabsViewModel)!

        // wait until Home page loads
        try await eNewtabPageLoaded.value
        try await eNewtab2PageLoaded.value

        // navigate to a failing url
        let eNavigationFailed = tab1.$error.compactMap { $0 }.timeout(5).first().promise()
        let eErrorPageLoaded = tab1.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        schemeHandler.middleware = [{ _ in
            .failure(NSError.noConnection)
        }]

        tab1.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        // wait for error page to open
        _=try await eNavigationFailed.value
        _=try await eErrorPageLoaded.value

        // switch to tab 2
        tabsViewModel.select(at: .unpinned(1))

        // next load should be ok
        let eServerQueried = expectation(description: "server request sent")
        let eNavigationSucceeded = tab1.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        schemeHandler.middleware = [{ _ in
            eServerQueried.fulfill()
            return .ok(.html(Self.testHtml))
        }]
        // coming back to the failing tab 1 should trigger its reload
        tabsViewModel.select(at: .unpinned(0))

        await fulfillment(of: [eServerQueried], timeout: 5)
        _=try await eNavigationSucceeded.value
        XCTAssertEqual(tab1.content.urlForWebView, .test)
        XCTAssertNil(tab1.error)
    }

    @MainActor
    func testWhenTabWithConnectionLostErrorActivatedAndReloadFailsAgain_errorPageIsShownOnce() async throws {
        // open 2 Tabs with newtab page
        // navigate to a failing url right away
        schemeHandler.middleware = [{ _ in
            .failure(NSError.connectionLost)
        }]
        let tab1 = Tab(content: .url(.test, source: .link), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let tab2 = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNavigationFailed = tab1.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished = tab1.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        let tabsViewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab1, tab2]))
        window = WindowsManager.openNewWindow(with: tabsViewModel)!

        // wait for error page to open
        _=try await eNavigationFailed.value
        _=try await eNavigationFinished.value

        // switch to tab 2
        tabsViewModel.select(at: .unpinned(1))

        // coming back to the failing tab 1 should trigger its reload but it will fail again
        let eServerQueried = expectation(description: "server request sent")
        schemeHandler.middleware = [{ _ in
            eServerQueried.fulfill()
            return .failure(NSError.noConnection)
        }]
        let eNavigationFailed2 = tab1.$error.compactMap { $0 }.filter {
            $0.errorCode == NSError.noConnection.code
        }.timeout(5).first().promise()

        tabsViewModel.select(at: .unpinned(0))

        await fulfillment(of: [eServerQueried], timeout: 1)
        let error = try await eNavigationFailed2.value

        let c = tab1.$isLoading.dropFirst().sink { isLoading in
            XCTFail("Failing tab shouldn‘t reload again (isLoading: \(isLoading))")
        }

        XCTAssertEqual(error.errorCode, NSError.noConnection.code)
        XCTAssertEqual(error.localizedDescription, NSError.noConnection.localizedDescription)
        let headerText: String? = try await tab1.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab1.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")
        XCTAssertNil(tab1.title)
        XCTAssertEqual(tabsViewModel.tabViewModel(at: 0)?.title, UserText.tabErrorTitle)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.noConnection.localizedDescription)

        try await Task.sleep(interval: 0.4) // sleep a little to confirm no more navigations are performed
        withExtendedLifetime(c) {}
    }

    @MainActor
    func testWhenTabWithOtherErrorActivated_reloadNotTriggered() async throws {
        // open 2 Tabs with newtab page
        // navigate to a failing url right away
        schemeHandler.middleware = [{ _ in
            .failure(NSError.hostNotFound)
        }]
        let tab1 = Tab(content: .url(.test, source: .link), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let tab2 = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNavigationFailed = tab1.$error.compactMap { $0 }.timeout(5).first().promise()
        let errorNavigationFinished = tab1.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let tabsViewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab1, tab2]))
        window = WindowsManager.openNewWindow(with: tabsViewModel)!

        // wait for error page to open
        _=try await eNavigationFailed.value
        _=try await errorNavigationFinished.value

        // switch to tab 2
        tabsViewModel.select(at: .unpinned(1))

        // coming back to the failing tab 1 should not trigger reload
        let c = tab1.$isLoading.filter { $0 == true }.sink { isLoading in
            XCTFail("Failing tab shouldn‘t reload again (isLoading: \(isLoading))")
        }
        tabsViewModel.select(at: .unpinned(0))

        try await Task.sleep(interval: 0.4) // sleep a little to confirm no more navigations are performed
        withExtendedLifetime(c) {}
    }

    @MainActor
    func testWhenGoingBackToFailingPage_reloadIsTriggered() async throws {
        // open Tab with newtab page
        // navigate to a failing url right away
        schemeHandler.middleware = [{ _ in
            .failure(NSError.hostNotFound)
        }]
        let tab = Tab(content: .url(.test, source: .link), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let errorNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        window = WindowsManager.openNewWindow(with: tab)!

        // wait for navigation to fail
        _=try await eNavigationFailed.value
        _=try await errorNavigationFinished.value

        let ePageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        // navigate to test url: success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.alternativeHtml))
        }]
        tab.setContent(.url(.alternative, source: .userEntered(URL.test.absoluteString)))

        try await ePageLoaded.value

        // navigate back to failing page: success
        let eBackPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let eRequestSent = expectation(description: "request sent")
        schemeHandler.middleware = [{ _ in
            eRequestSent.fulfill()
            return .ok(.html(Self.testHtml))
        }]
        tab.goBack()
        try await eBackPageLoaded.value
        await fulfillment(of: [eRequestSent])

        let titleText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByTagName('title')[0].innerText")
        XCTAssertEqual(titleText, Self.pageTitle)
        XCTAssertEqual(tab.title, titleText)
        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertEqual(tab.currentHistoryItem?.title, titleText)

        XCTAssertEqual(tab.backHistoryItems.count, 0)
        XCTAssertFalse(tab.canGoBack)

        XCTAssertEqual(tab.forwardHistoryItems.count, 1)
        XCTAssertEqual(tab.forwardHistoryItems.first?.url, .alternative)
        XCTAssertEqual(tab.forwardHistoryItems.first?.title, Self.alternativeTitle)
        XCTAssertTrue(tab.canGoForward)

        XCTAssertTrue(tab.canReload)
    }

    @MainActor
    func testWhenGoingBackToFailingPageAndItFailsAgain_errorPageIsUpdated() async throws {
        // open Tab with newtab page
        // navigate to a failing url right away
        schemeHandler.middleware = [{ _ in
            .failure(NSError.hostNotFound)
        }]
        let tab = Tab(content: .url(.test, source: .link), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let errorNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        window = WindowsManager.openNewWindow(with: tab)!

        // wait for navigation to fail
        _=try await eNavigationFailed.value
        _=try await errorNavigationFinished.value

        let ePageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        // navigate to test url: success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.alternativeHtml))
        }]
        tab.setContent(.url(.alternative, source: .userEntered(URL.test.absoluteString)))

        try await ePageLoaded.value

        // navigate back to failing page: failure
        let eBackPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let eNavigationFailed2 = tab.$error.compactMap { $0 }.filter {
            $0.errorCode == NSError.noConnection.code
        }.timeout(5).first().promise()

        schemeHandler.middleware = [{ _ in
            .failure(NSError.noConnection)
        }]
        tab.goBack()
        _=try await eNavigationFailed2.value
        _=try await eBackPageLoaded.value

        let headerText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")
        XCTAssertNil(tab.title)
        XCTAssertEqual(tabViewModel.title, UserText.tabErrorTitle)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.noConnection.localizedDescription)

        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertNil(tab.currentHistoryItem?.title)

        XCTAssertEqual(tab.backHistoryItems.count, 0)
        XCTAssertFalse(tab.canGoBack)

        XCTAssertEqual(tab.forwardHistoryItems.count, 1)
        XCTAssertEqual(tab.forwardHistoryItems.first?.url, .alternative)
        XCTAssertEqual(tab.forwardHistoryItems.first?.title, Self.alternativeTitle)
        XCTAssertTrue(tab.canGoForward)

        XCTAssertTrue(tab.canReload)
    }

    @MainActor
    func testWhenPageLoadedAndFailsOnRefreshAndOnConsequentRefresh_errorPageIsUpdatedKeepingForwardHistory() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await eNewtabPageLoaded.value

        // navigate to test url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.testHtml))
        }]
        let eNavigationFinished2 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        _=try await eNavigationFinished2.value

        // navigate to another url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.alternativeHtml))
        }]
        let eNavigationFinished3 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.alternative, source: .userEntered(URL.alternative.absoluteString)))
        _=try await eNavigationFinished3.value

        // navigate back
        let eBackNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.goBack()
        _=try await eBackNavigationFinished.value

        // refresh: fail
        schemeHandler.middleware = [{ _ in
            .failure(NSError.noConnection)
        }]
        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished4 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.reload()
        _=try await eNavigationFailed.value
        _=try await eNavigationFinished4.value

        // refresh again: fail
        let eServerQueried = expectation(description: "server request sent")
        schemeHandler.middleware = [{ _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                eServerQueried.fulfill()
            }
            return .failure(NSError.connectionLost)
        }]
        let eNavigationFailed2 = tab.$error.compactMap { $0 }.timeout(5).first().promise()

        tab.reload()
        _=try await eNavigationFailed2.value
        await fulfillment(of: [eServerQueried])

        let headerText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")
        XCTAssertNil(tab.title)
        XCTAssertEqual(tabViewModel.title, UserText.tabErrorTitle)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.connectionLost.localizedDescription)

        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertEqual(tab.currentHistoryItem?.title, Self.pageTitle)

        XCTAssertEqual(tab.backHistoryItems.count, 1)
        XCTAssertEqual(tab.backHistoryItems.first?.url, .newtab, "url")
        XCTAssertTrue(tab.canGoBack)

        XCTAssertEqual(tab.forwardHistoryItems.count, 1)
        XCTAssertEqual(tab.forwardHistoryItems.first?.url, .alternative, "url")
        XCTAssertEqual(tab.forwardHistoryItems.first?.title, Self.alternativeTitle, "title")
        XCTAssertTrue(tab.canGoForward)

        XCTAssertTrue(tab.canReload)
    }

    @MainActor
    func testWhenPageLoadedAndFailsOnRefreshAndSucceedsOnConsequentRefresh_forwardHistoryIsPreserved() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await eNewtabPageLoaded.value

        // navigate to test url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.testHtml))
        }]
        let eNavigationFinished2 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        _=try await eNavigationFinished2.value

        // navigate to another url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.alternativeHtml))
        }]
        let eNavigationFinished3 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.alternative, source: .userEntered(URL.alternative.absoluteString)))
        _=try await eNavigationFinished3.value

        // navigate back
        let eBackNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.goBack()
        _=try await eBackNavigationFinished.value

        // refresh: fail
        schemeHandler.middleware = [{ _ in
            .failure(NSError.noConnection)
        }]
        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished4 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.reload()
        _=try await eNavigationFailed.value
        _=try await eNavigationFinished4.value

        // refresh again: success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.testHtml))
        }]
        let eNavigationFinished5 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.reload()
        _=try await eNavigationFinished5.value

        let titleText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByTagName('title')[0].innerText")
        XCTAssertEqual(tab.title, Self.pageTitle)
        XCTAssertEqual(titleText?.trimmingWhitespace(), tab.title)

        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertEqual(tab.currentHistoryItem?.title, Self.pageTitle)

        XCTAssertEqual(tab.backHistoryItems.count, 1)
        XCTAssertEqual(tab.backHistoryItems.first?.url, .newtab)
        XCTAssertTrue(tab.canGoBack)

        XCTAssertEqual(tab.forwardHistoryItems.count, 1)
        XCTAssertEqual(tab.forwardHistoryItems.first?.url, .alternative)
        XCTAssertEqual(tab.forwardHistoryItems.first?.title, Self.alternativeTitle)
        XCTAssertTrue(tab.canGoForward)

        XCTAssertTrue(tab.canReload)
    }

    @MainActor
    func testWhenReloadingBySubmittingSameURL_errorPageRemainsSame() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await eNewtabPageLoaded.value

        // navigate to test url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.testHtml))
        }]
        let eNavigationFinished2 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        _=try await eNavigationFinished2.value

        // navigate to another url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.alternativeHtml))
        }]
        let eNavigationFinished3 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.alternative, source: .userEntered(URL.alternative.absoluteString)))
        _=try await eNavigationFinished3.value

        // navigate back
        let eBackNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.goBack()
        _=try await eBackNavigationFinished.value

        // refresh: fail
        schemeHandler.middleware = [{ _ in
            .failure(NSError.noConnection)
        }]
        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished4 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        _=try await eNavigationFailed.value
        _=try await eNavigationFinished4.value

        // refresh again: fail
        let eServerQueried = expectation(description: "server request sent")
        schemeHandler.middleware = [{ _ in
            eServerQueried.fulfill()
            return .failure(NSError.connectionLost)
        }]

        /// Set content before subscribing to `tab.$error.compactMap { $0 }` to allow
        /// for error to be nullified first by the call to `setContent`.
        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        let eNavigationFailed2 = tab.$error.compactMap { $0 }.timeout(5).first().promise()

        _=try await eNavigationFailed2.value
        await fulfillment(of: [eServerQueried])

        let headerText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")
        XCTAssertNil(tab.title)
        XCTAssertEqual(tabViewModel.title, UserText.tabErrorTitle)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.connectionLost.localizedDescription)

        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertEqual(tab.currentHistoryItem?.title, Self.pageTitle)

        XCTAssertEqual(tab.backHistoryItems.count, 1)
        XCTAssertEqual(tab.backHistoryItems.first?.url, .newtab, "url")
        XCTAssertNil(tab.backHistoryItems.first?.title, "title")
        XCTAssertTrue(tab.canGoBack)

        XCTAssertEqual(tab.forwardHistoryItems.count, 1)
        XCTAssertEqual(tab.forwardHistoryItems.first?.url, .alternative, "url")
        XCTAssertEqual(tab.forwardHistoryItems.first?.title, Self.alternativeTitle, "title")
        XCTAssertTrue(tab.canGoForward)

        XCTAssertTrue(tab.canReload)
    }

    @MainActor
    func testWhenGoingToAnotherUrlFails_newBackForwardHistoryItemIsAdded() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await eNewtabPageLoaded.value

        // navigate to test url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.testHtml))
        }]
        let eNavigationFinished2 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        _=try await eNavigationFinished2.value

        // navigate to another url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.alternativeHtml))
        }]
        let eNavigationFinished3 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.alternative, source: .userEntered(URL.alternative.absoluteString)))
        _=try await eNavigationFinished3.value

        // navigate back
        let eBackNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.goBack()
        _=try await eBackNavigationFinished.value

        // refresh: fail
        schemeHandler.middleware = [{ _ in
            .failure(NSError.noConnection)
        }]
        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished4 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        _=try await eNavigationFailed.value
        _=try await eNavigationFinished4.value

        // go to another url: fail
        let eServerQueried = expectation(description: "server request sent")
        schemeHandler.middleware = [{ _ in
            eServerQueried.fulfill()
            return .failure(NSError.connectionLost)
        }]

        /// Set content before subscribing to `tab.$error.compactMap { $0 }` to allow
        /// for error to be nullified first by the call to `setContent`.
        tab.setContent(.url(.alternative, source: .userEntered(URL.alternative.absoluteString)))
        let eNavigationFailed2 = tab.$error.compactMap { $0 }.timeout(5).first().promise()

        _=try await eNavigationFailed2.value
        await fulfillment(of: [eServerQueried])

        let headerText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")
        XCTAssertNil(tab.title)
        XCTAssertEqual(tabViewModel.title, UserText.tabErrorTitle)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.connectionLost.localizedDescription)

        XCTAssertEqual(tab.currentHistoryItem?.url, .alternative)
        XCTAssertNil(tab.currentHistoryItem?.title)

        XCTAssertEqual(tab.backHistoryItems.count, 2)
        XCTAssertEqual(tab.backHistoryItems[safe: 0]?.url, .newtab)
        XCTAssertNil(tab.backHistoryItems[safe: 0]?.title)
        XCTAssertEqual(tab.backHistoryItems[safe: 1]?.url, .test)
        XCTAssertEqual(tab.backHistoryItems[safe: 1]?.title, Self.pageTitle)
        XCTAssertTrue(tab.canGoBack)

        XCTAssertEqual(tab.forwardHistoryItems.count, 0)
        XCTAssertFalse(tab.canGoForward)

        XCTAssertTrue(tab.canReload)
    }

    @MainActor
    func testWhenGoingToAnotherUrlSucceeds_newBackForwardHistoryItemIsAdded() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await eNewtabPageLoaded.value

        // navigate to test url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.testHtml))
        }]
        let eNavigationFinished2 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        _=try await eNavigationFinished2.value

        // navigate to another url, success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.alternativeHtml))
        }]
        let eNavigationFinished3 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.url(.alternative, source: .userEntered(URL.alternative.absoluteString)))
        _=try await eNavigationFinished3.value

        // navigate back
        let eBackNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.goBack()
        _=try await eBackNavigationFinished.value

        // refresh: fail
        schemeHandler.middleware = [{ _ in
            .failure(NSError.noConnection)
        }]
        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished4 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.setContent(.url(.test, source: .userEntered(URL.test.absoluteString)))
        _=try await eNavigationFailed.value
        _=try await eNavigationFinished4.value

        // go to another url: success
        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.alternativeHtml))
        }]
        let eNavigationFinished5 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.setContent(.url(.alternative, source: .userEntered(URL.alternative.absoluteString)))
        _=try await eNavigationFinished5.value

        let titleText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByTagName('title')[0].innerText")
        XCTAssertEqual(tab.title, Self.alternativeTitle)
        XCTAssertEqual(titleText?.trimmingWhitespace(), tab.title)

        XCTAssertEqual(tab.currentHistoryItem?.url, .alternative)
        XCTAssertEqual(tab.currentHistoryItem?.title, Self.alternativeTitle)

        XCTAssertEqual(tab.backHistoryItems.count, 2)
        XCTAssertEqual(tab.backHistoryItems[safe: 0]?.url, .newtab)
        XCTAssertNil(tab.backHistoryItems[safe: 0]?.title)
        XCTAssertEqual(tab.backHistoryItems[safe: 1]?.url, .test)
        XCTAssertEqual(tab.backHistoryItems[safe: 1]?.title, Self.pageTitle)
        XCTAssertTrue(tab.canGoBack)

        XCTAssertEqual(tab.forwardHistoryItems.count, 0)
        XCTAssertFalse(tab.canGoForward)

        XCTAssertTrue(tab.canReload)
    }

    @MainActor
    func testWhenLoadingFailsAfterSessionRestoration_navigationHistoryIsPreserved() async throws {
        schemeHandler.middleware = [{ _ in
            .failure(NSError.noConnection)
        }]

        let tab = Tab(content: .url(.test, source: .pendingStateRestoration), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, interactionStateData: Self.sessionStateData)
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await eNewtabPageLoaded.value

        XCTAssertTrue(tab.canReload)

        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.testHtml))
        }]
        // open new tab
        viewModel.append(tab: Tab(content: .newtab, privacyFeatures: privacyFeaturesMock))

        // select the failing tab triggering its reload
        let eReloadFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        viewModel.select(at: .unpinned(0))
        _=try await eReloadFinished.value

        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertEqual(tab.currentHistoryItem?.title, Self.pageTitle)

        XCTAssertEqual(tab.backHistoryItems.count, 1)
        XCTAssertEqual(tab.backHistoryItems.first?.url, .newtab)
        XCTAssertEqual(tab.backHistoryItems.first?.title ?? "", "")
        XCTAssertTrue(tab.canGoBack)

        XCTAssertEqual(tab.forwardHistoryItems.count, 1)
        XCTAssertEqual(tab.forwardHistoryItems.first?.url, .alternative)
        XCTAssertEqual(tab.forwardHistoryItems.first?.title, Self.alternativeTitle)
        XCTAssertTrue(tab.canGoForward)

        XCTAssertTrue(tab.canReload)
    }

    @MainActor
    func testPinnedTabDoesNotNavigateAway() async throws {
        schemeHandler.middleware = [{ _ in
            return .ok(.html(Self.testHtml))
        }]

        let tab = Tab(content: .url(.alternative, source: .ui), webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let eNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        let manager = PinnedTabsManager()
        manager.pin(tab)

        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: []), pinnedTabsManager: manager)
        window = WindowsManager.openNewWindow(with: viewModel)!
        viewModel.select(at: .pinned(0))
        let webViewShownPromise = tab.webView.publisher(for: \.superview).compactMap { $0 }.timeout(5).first().promise()

        // wait for tab to load
        _=try await eNavigationFinished.value
        _=try await webViewShownPromise.value

        // refresh: fail
        let failureExpectation = expectation(description: "request failed")
        schemeHandler.middleware = [{ _ in
            failureExpectation.fulfill()
            return .failure(NSError.noConnection)
        }]
        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished2 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.reload()
        _=try await eNavigationFailed.value
        _=try await eNavigationFinished2.value
        await fulfillment(of: [failureExpectation], timeout: 5)

        XCTAssertNotNil(tab.error)

        schemeHandler.middleware = [{ _ in
            .ok(.html(Self.testHtml))
        }]
        let eNavigationFinished5 = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        tab.reload()
        _=try await eNavigationFinished5.value

        XCTAssertNil(tab.error)
        XCTAssertEqual(viewModel.tabs.count, 1)
    }

    @MainActor
    func testWhenPageFailsToLoadAfterRedirect_errorPageShown() async throws {
        // open Tab with newtab page
        let tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        window = WindowsManager.openNewWindow(with: viewModel)!
        try await eNewtabPageLoaded.value

        // navigate to alt url, redirect to test url, fail with error
        schemeHandler.middleware = [{ request in
            .redirect(to: .test, with: NSError.hostNotFound)
        }]
        tab.setContent(.url(.test, source: .userEntered(URL.alternative.absoluteString)))

        let eNavigationFailed = tab.$error.compactMap { $0 }.timeout(5).first().promise()
        let eNavigationFinished = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()

        let error = try await eNavigationFailed.value
        _=try await eNavigationFinished.value

        XCTAssertEqual(error.errorCode, NSError.hostNotFound.code)
        XCTAssertEqual(error.localizedDescription, NSError.hostNotFound.localizedDescription)
        let headerText: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-header')[0].innerText")
        let errorDescr: String? = try await tab.webView.evaluateJavaScript("document.getElementsByClassName('error-description')[0].innerText")

        XCTAssertNil(tab.title)
        XCTAssertEqual(tabViewModel.title, UserText.tabErrorTitle)
        XCTAssertEqual(headerText?.trimmingWhitespace(), UserText.errorPageHeader)
        XCTAssertEqual(errorDescr?.trimmingWhitespace(), NSError.hostNotFound.localizedDescription)
        XCTAssertTrue(tab.canGoBack)
        XCTAssertFalse(tab.canGoForward)
        XCTAssertTrue(tab.canReload)
        XCTAssertFalse(viewModel.tabViewModel(at: 0)!.canSaveContent)
        XCTAssertEqual(tab.backHistoryItems.count, 1)
        XCTAssertEqual(tab.backHistoryItems.first?.url, .newtab)
        XCTAssertNil(tab.currentHistoryItem?.title)
        XCTAssertEqual(tab.currentHistoryItem?.url, .test)
        XCTAssertEqual(tab.content.userEditableUrl, .test)
    }

}

private extension URL {
    static let test = URL(string: "https://test.com/")!
    static let alternative = URL(string: "https://alternative.com/")!
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

extension Data {

    static let sessionRestorationMagic = Data([0x00, 0x00, 0x00, 0x02])

}
