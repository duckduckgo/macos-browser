//
//  OnboardingPageTests.swift
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

import XCTest
import Combine
import Common
@testable import DuckDuckGo_Privacy_Browser

final class OnboardingPageTests: XCTestCase {

    var webViewConfiguration: WKWebViewConfiguration!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var window: NSWindow!
    var mainViewController: MainViewController {
        (window.contentViewController as! MainViewController)
    }
    var tabViewModel: TabViewModel {
        mainViewController.browserTabViewController.tabViewModel!
    }
    var tab: Tab!

    @MainActor
    override func setUp() {
        super.setUp()
        _=WKUserContentController.swizzleScriptMessageHandlerWithReplyMethodsOnce
        webViewConfiguration = WKWebViewConfiguration()
        let contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        tab = Tab(content: .newtab, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock)
    }

    override func tearDown()  {
        window?.close()
        window = nil
        tab = nil
        super.tearDown()
    }

    @MainActor func testWhenTabInitialisedSpeacialPagesHandlersAdded() throws {
        let tab = Tab(content: .onboarding)
        let ucc = try XCTUnwrap(tab.userContentController)

        XCTAssertTrue(ucc.registeredScriptHandlerNames.contains("specialPages"))
    }

    @available(macOS 12.0, *)
    @MainActor func testWhenNavigatingToOnboarding_OnboardingPageIsPresented() async throws {
        // Given
        let viewModel = TabCollectionViewModel(tabCollection: TabCollection(tabs: [tab]))
        let eNewtabPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        window = try XCTUnwrap(WindowsManager.openNewWindow(with: viewModel))
        try await eNewtabPageLoaded.value

        // When
        let eOnboardingPageLoaded = tab.webViewDidFinishNavigationPublisher.timeout(5).first().promise()
        tab.setContent(.onboarding)
        try await eOnboardingPageLoaded.value

        // Then
        extractHTML(from: tab.webView) { htmlContent, error in
            XCTAssertNotNil(htmlContent)
            XCTAssertNil(error)
            XCTAssertTrue(htmlContent?.contains("<title>Welcome</title>") ?? false)
        }
        XCTAssertEqual(tab.title, "Welcome")
        XCTAssertEqual(tabViewModel.title, "Welcome")
    }

    private func extractHTML(from webView: WKWebView, completion: @escaping (String?, Error?) -> Void) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { (html, error) in
            if let htmlContent = html as? String {
                completion(htmlContent, nil)
            } else if let error = error {
                completion(nil, error)
            } else {
                completion(nil, NSError(domain: "WebViewError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
            }
        }
    }

}

extension WKUserContentController {
    private static let scriptHandlersKey = UnsafeRawPointer(bitPattern: "scriptHandlersKey".hashValue)!

    private static var installedScriptHandlers: [(WKScriptMessageHandlerWithReply, WKContentWorld, String)] {
        get {
            objc_getAssociatedObject(self, scriptHandlersKey) as? [(WKScriptMessageHandlerWithReply, WKContentWorld, String)] ?? []
        }
        set {
            objc_setAssociatedObject(self, scriptHandlersKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    static let swizzleScriptMessageHandlerWithReplyMethodsOnce: Void = {
        let originalAddMethod = class_getInstanceMethod(WKUserContentController.self, #selector(WKUserContentController.addScriptMessageHandler(_:contentWorld:name:)))!
        let swizzledAddMethod = class_getInstanceMethod(WKUserContentController.self, #selector(swizzled_addScriptMessageHandler(_:contentWorld:name:)))!
        method_exchangeImplementations(originalAddMethod, swizzledAddMethod)
    }()

    @objc dynamic private func swizzled_addScriptMessageHandler(_ scriptMessageHandlerWithReply: WKScriptMessageHandlerWithReply, contentWorld: WKContentWorld, name: String) {
        // Append the handler to our array
        Self.installedScriptHandlers.append((scriptMessageHandlerWithReply, contentWorld, name))

        // Call the original method
        swizzled_addScriptMessageHandler(scriptMessageHandlerWithReply, contentWorld: contentWorld, name: name)
    }

    var registeredScriptHandlerNames: [String] {
        return Self.installedScriptHandlers.map { $0.2 }
    }

    var registeredScriptHandlers: [(WKScriptMessageHandlerWithReply, WKContentWorld, String)] {
        return Self.installedScriptHandlers
    }
}
