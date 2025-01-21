//
//  SearchNonexistentDomainTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Carbon
import Combine
import Navigation
import XCTest
import History
import Common

@testable import DuckDuckGo_Privacy_Browser

// swiftlint:disable opening_brace
@available(macOS 12.0, *)
final class SearchNonexistentDomainTests: XCTestCase {

    struct URLs {
        let validTLD = URL(string: "https://testhost.com/")!
        let invalidTLD = URL(string: "https://testhost.coma/")!
    }
    let urls = URLs()

    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }

    var webViewConfiguration: WKWebViewConfiguration!
    var schemeHandler: TestSchemeHandler!

    var window: NSWindow!

    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }

    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }

    var addressBar: AddressBarTextField! {
        mainViewController.navigationBarViewController.addressBarViewController?.addressBarTextField
    }

    override func setUp() {
        contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }

        schemeHandler = TestSchemeHandler()
        WKWebView.customHandlerSchemes = [.http, .https]

        webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.http.rawValue)
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.https.rawValue)
    }

    @MainActor
    override func tearDown() async throws {
        window?.close()
        window = nil

        contentBlockingMock = nil
        privacyFeaturesMock = nil
        webViewConfiguration = nil
        schemeHandler = nil
        WKWebView.customHandlerSchemes = []
    }

    // MARK: - Tests

    @MainActor
    func testWhenNonexistentDomainRequested_redirectedToSERP() async throws {
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = urls.invalidTLD
        let enteredString = url.absoluteString.dropping(prefix: url.navigationalScheme!.separated())

        let eRedirected = expectation(description: "Redirected to SERP")
        self.schemeHandler.middleware = [{ request in
            if request.url!.isDuckDuckGoSearch {
                XCTAssertEqual(request.url, URL.makeSearchUrl(from: enteredString))
                eRedirected.fulfill()
                return .ok(.html(""))
            } else {
                return .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost))
            }
        }]

        addressBar.makeMeFirstResponder()
        addressBar.stringValue = enteredString

        NSApp.swizzled_currentEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0, context: nil, characters: "\n", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(kVK_Return))!
        _=addressBar.control(addressBar, textView: addressBar.currentEditor() as! NSTextView, doCommandBy: #selector(NSResponder.insertNewline))

        await fulfillment(of: [eRedirected], timeout: 3)
    }

    @MainActor
    func testWhenNonexistentDomainRequestedWithValidTLD_notRedirectedToSERP() async throws {
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        self.schemeHandler.middleware = [{ request in
            XCTAssertFalse(request.url!.isDuckDuckGoSearch)
            return .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost))
        }]
        let eNavigationFailed = tab.$error
            .compactMap { $0 }
            .timeout(3)
            .first()
            .promise()
        // error page navigation
        let eNavigationDidFinish = tab.webViewDidFinishNavigationPublisher
            .timeout(3)
            .first()
            .promise()

        let url = urls.validTLD
        let enteredString = url.absoluteString.dropping(prefix: url.navigationalScheme!.separated())

        addressBar.makeMeFirstResponder()
        addressBar.stringValue = enteredString

        NSApp.swizzled_currentEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0, context: nil, characters: "\n", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(kVK_Return))!
        _=addressBar.control(addressBar, textView: addressBar.currentEditor() as! NSTextView, doCommandBy: #selector(NSResponder.insertNewline))

        let error = try await eNavigationFailed.value
        _=try await eNavigationDidFinish.value
        XCTAssertEqual(error.errorCode, NSURLErrorCannotFindHost)
    }

    @MainActor
    func testWhenNonexistentDomainRequestedWithScheme_notRedirectedToSERP() async throws {
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        self.schemeHandler.middleware = [{ request in
            XCTAssertFalse(request.url!.isDuckDuckGoSearch)
            return .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost))
        }]
        let eNavigationFailed = tab.$error
            .compactMap { $0 }
            .timeout(3)
            .first()
            .promise()
        // error page navigation
        let eNavigationDidFinish = tab.webViewDidFinishNavigationPublisher
            .timeout(3)
            .first()
            .promise()

        let url = urls.invalidTLD
        let enteredString = url.absoluteString

        addressBar.makeMeFirstResponder()
        addressBar.stringValue = enteredString

        NSApp.swizzled_currentEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0, context: nil, characters: "\n", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(kVK_Return))!
        _=addressBar.control(addressBar, textView: addressBar.currentEditor() as! NSTextView, doCommandBy: #selector(NSResponder.insertNewline))

        let error = try await eNavigationFailed.value
        _=try await eNavigationDidFinish.value
        XCTAssertEqual(error.errorCode, NSURLErrorCannotFindHost)
    }

    @MainActor
    func testWhenNonexistentDomainNotEnteredByUser_notRedirectedToSERP() async throws {
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        self.schemeHandler.middleware = [{ request in
            XCTAssertFalse(request.url!.isDuckDuckGoSearch)
            return .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost))
        }]
        let eNavigationFailed = tab.$error
            .compactMap { $0 }
            .timeout(3)
            .first()
            .promise()
        // error page navigation
        let eNavigationDidFinish = tab.webViewDidFinishNavigationPublisher
            .timeout(10)
            .first()
            .promise()

        let url = urls.invalidTLD

        tab.setUrl(url, source: .link)

        let error = try await eNavigationFailed.value
        _=try await eNavigationDidFinish.value
        XCTAssertEqual(error.errorCode, NSURLErrorCannotFindHost)
    }

    @MainActor
    func testWhenNonexistentDomainSuggestionChosen_redirectedToSERP() async throws {
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
        window = WindowsManager.openNewWindow(with: tab)!

        let url = urls.invalidTLD
        let enteredString = url.absoluteString.dropping(prefix: url.navigationalScheme!.separated())

        let eRedirected = expectation(description: "Redirected to SERP")
        self.schemeHandler.middleware = [{ request in
            if request.url!.isDuckDuckGoSearch {
                XCTAssertEqual(request.url, URL.makeSearchUrl(from: enteredString))
                eRedirected.fulfill()

                return .ok(.html(""))
            } else {
                return .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost))
            }
        }]

        addressBar.makeMeFirstResponder()
        addressBar.stringValue = enteredString

        let suggestionLoadingMock = SuggestionLoadingMock()
        let suggestionContainer = SuggestionContainer(openTabsProvider: { [] },
                                                      suggestionLoading: suggestionLoadingMock,
                                                      historyCoordinating: HistoryCoordinator.shared,
                                                      bookmarkManager: LocalBookmarkManager.shared,
                                                      burnerMode: .regular)
        addressBar.suggestionContainerViewModel = SuggestionContainerViewModel(isHomePage: true, isBurner: false, suggestionContainer: suggestionContainer)

        suggestionContainer.getSuggestions(for: enteredString)
        suggestionLoadingMock.completion!(.init(topHits: [.website(url: url)], duckduckgoSuggestions: [], localSuggestions: []), nil)

        addressBar.suggestionViewControllerDidConfirmSelection(addressBar.suggestionViewController)

        await fulfillment(of: [eRedirected], timeout: 3)
    }

}
