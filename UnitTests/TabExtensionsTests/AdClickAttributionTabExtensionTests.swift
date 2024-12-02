//
//  AdClickAttributionTabExtensionTests.swift
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
import Combine
import ContentBlocking
import Navigation
import os.log
import TrackerRadarKit
import WebKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

// swiftlint:disable opening_brace

@available(macOS 12.0, *)
class AdClickAttributionTabExtensionTests: XCTestCase {
    struct URLs {
        let url1 = URL(string: "https://my-host.com/")!
        let url2 = URL(string: "http://another-host.org/1")!
        let url3 = URL(string: "http://another-host.org/2")!
    }
    struct DataSource {
        let empty = Data()
        let html = """
            <html>
                <body>
                    some data
                    <a id="navlink" />
                </body>
            </html>
        """.utf8data
        let metaRedirect = """
        <html>
            <head>
                <meta http-equiv="Refresh" content="0; URL=http://another-host.org/1" />
            </head>
        </html>
        """.utf8data
    }

    let urls = URLs()
    let data = DataSource()

    let logic = MockAdClickLogic()
    let detection = MockAdClickDetection()
    let contentBlockerRulesScriptSubj = CurrentValueSubject<ContentBlockerScriptProtocol?, Never>(nil)
    var contentBlockerRulesScript: MockContentBlockerRulesUserScript!
    let userContentController = UserContentControllerMock()
    let trackerInfoPublisher = PassthroughSubject<DetectedRequest, Never>()
    let now = Date()

    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }
    var webViewConfiguration: WKWebViewConfiguration!
    var schemeHandler: TestSchemeHandler!
    var extensionsBuilder: TestTabExtensionsBuilder!

    var navExtension: TestsClosureNavigationResponderTabExtension!
    var decidePolicy: (NavigationAction) -> NavigationActionPolicy? = { _ in .next }

    @MainActor
    override func setUp() {
        contentBlockingMock = ContentBlockingMock(adClickAttributionEnabled: true)
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())

        navExtension = TestsClosureNavigationResponderTabExtension(.init { navAction, _ in
            self.decidePolicy(navAction)
        })

        extensionsBuilder = TestTabExtensionsBuilder(load: [AdClickAttributionTabExtension.self]) { [unowned self] builder in { args, dependencies in
            builder.override {
                AdClickAttributionTabExtension(inheritedAttribution: args.inheritedAttribution,
                                               userContentControllerFuture: Future { fulfill in DispatchQueue.main.async { fulfill(.success(self.userContentController)) } },
                                               contentBlockerRulesScriptPublisher: self.contentBlockerRulesScriptSubj,
                                               trackerInfoPublisher: self.trackerInfoPublisher,
                                               dependencies: dependencies.privacyFeatures.contentBlocking,
                                               dateTimeProvider: { self.now }) { _ in
                    (logic: self.logic, detection: self.detection)
                }
            }
            builder.add {
                self.navExtension
            }
        }}

        schemeHandler = TestSchemeHandler()
        schemeHandler.middleware = [{ [data] in
            Logger.tests.debug("schemeHandler.middleware \($0.url?.absoluteString ?? "<nil>", privacy: .public)")
            return .ok(.html(data.html.utf8String()!))
        }]

        WKWebView.customHandlerSchemes = [.http, .https]

        webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.http.rawValue)
        webViewConfiguration.setURLSchemeHandler(schemeHandler, forURLScheme: URL.NavigationalScheme.https.rawValue)
    }

    func makeContentBlockerRulesUserScript() {
        contentBlockerRulesScript = MockContentBlockerRulesUserScript()
        Logger.tests.debug("➡️ contentBlockerRulesScriptSubj.send(MockContentBlockerRulesUserScript)")
        contentBlockerRulesScriptSubj.send(contentBlockerRulesScript)
    }

    override func tearDown() {
        WKWebView.customHandlerSchemes = []

        extensionsBuilder = nil
        contentBlockingMock = nil
        privacyFeaturesMock = nil
        contentBlockerRulesScript = nil
        webViewConfiguration = nil
        schemeHandler = nil
    }

    // MARK: - Tests

    @MainActor
    func testWhenChildTabCreated_AdClickAttributionStateIsSet() {

        class MockAttribution: TabExtension, AdClickAttributionProtocol {
            private struct SessionInfoMock {
                // Start of the attribution
                public let attributionStartedAt = Date()
                // Present when we leave webpage associated with the attribution
                public let leftAttributionContextAt: Date? = nil
            }

            var currentAttributionState: BrowserServicesKit.AdClickAttributionLogic.State = {
                let ruleListMock = NSObject()
                let ruleList = withUnsafePointer(to: ruleListMock) { $0.withMemoryRebound(to: WKContentRuleList.self, capacity: 1) { $0 } }.pointee
                return .activeAttribution(vendor: "a", session: unsafeBitCast(SessionInfoMock(), to: AdClickAttributionLogic.SessionInfo.self), rules: .init(name: "name", rulesList: ruleList, trackerData: .mock, encodedTrackerData: "data", etag: "etag", identifier: .mock))
            }()

            func getPublicProtocol() -> AdClickAttributionProtocol {
                self
            }
        }
        let mockAttribution = MockAttribution()
        let mockBuilder = TestTabExtensionsBuilder(load: [AdClickAttributionTabExtension.self]) { builder in { _, _ in
            builder.override {
                mockAttribution
            }
        }}

        let parentTab = Tab(content: .none, extensionsBuilder: mockBuilder, shouldLoadInBackground: true)

        let onApplyInheritedAttribution = expectation(description: "onApplyInheritedAttribution")
        /*childTab*/logic.onApplyInheritedAttribution = { [unowned logic] in
            logic.state = $0!
            onApplyInheritedAttribution.fulfill()
        }
        let onInstallLocalContentRuleList = expectation(description: "onInstallLocalContentRuleList")
        userContentController.onInstallLocalContentRuleList = { _, _ in
            onInstallLocalContentRuleList.fulfill()
        }
        let onDisableGlobalContentRuleList = expectation(description: "onDisableGlobalContentRuleList")
        userContentController.onDisableGlobalContentRuleList = { _ in
            onDisableGlobalContentRuleList.fulfill()
        }
        logic.onRulesChanged = { _ in }

        let childTab = Tab(content: .none, extensionsBuilder: extensionsBuilder, parentTab: parentTab)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        waitForExpectations(timeout: 1)
        XCTAssertEqual(childTab.adClickAttribution?.currentAttributionState, mockAttribution.currentAttributionState)
    }

    @MainActor
    func testWhenChildTabCreatedAndScriptsAlreadyLoaded_AdClickAttributionStateIsSet() {

        class MockAttribution: TabExtension, AdClickAttributionProtocol {
            private struct SessionInfoMock {
                // Start of the attribution
                public let attributionStartedAt = Date()
                // Present when we leave webpage associated with the attribution
                public let leftAttributionContextAt: Date? = nil
            }

            var currentAttributionState: BrowserServicesKit.AdClickAttributionLogic.State = {
                let ruleListMock = NSObject()
                let ruleList = withUnsafePointer(to: ruleListMock) { $0.withMemoryRebound(to: WKContentRuleList.self, capacity: 1) { $0 } }.pointee
                return .activeAttribution(vendor: "a", session: unsafeBitCast(SessionInfoMock(), to: AdClickAttributionLogic.SessionInfo.self), rules: .init(name: "name", rulesList: ruleList, trackerData: .mock, encodedTrackerData: "data", etag: "etag", identifier: .mock))
            }()

            func getPublicProtocol() -> AdClickAttributionProtocol {
                self
            }
        }
        let mockAttribution = MockAttribution()
        let mockBuilder = TestTabExtensionsBuilder(load: [AdClickAttributionTabExtension.self]) { builder in { _, _ in
            builder.override {
                mockAttribution
            }
        }}

        let parentTab = Tab(content: .none, extensionsBuilder: mockBuilder, shouldLoadInBackground: true)

        let onApplyInheritedAttribution = expectation(description: "onApplyInheritedAttribution")
        /*childTab*/logic.onApplyInheritedAttribution = { [unowned logic] in
            logic.state = $0!
            onApplyInheritedAttribution.fulfill()
        }
        let onInstallLocalContentRuleList = expectation(description: "onInstallLocalContentRuleList")
        userContentController.onInstallLocalContentRuleList = { _, _ in
            onInstallLocalContentRuleList.fulfill()
        }
        let onDisableGlobalContentRuleList = expectation(description: "onDisableGlobalContentRuleList")
        userContentController.onDisableGlobalContentRuleList = { _ in
            onDisableGlobalContentRuleList.fulfill()
        }
        logic.onRulesChanged = { _ in }

        makeContentBlockerRulesUserScript()
        let childTab = Tab(content: .none, extensionsBuilder: extensionsBuilder, parentTab: parentTab)

        waitForExpectations(timeout: 1)
        XCTAssertEqual(childTab.adClickAttribution?.currentAttributionState, mockAttribution.currentAttributionState)
    }

    @MainActor
    func testWhenNavigationSucceeds_eventsSent() throws {
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }

        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        let onDetectionDidStart = expectation(description: "detection.onDidStart")
        detection.onDidStart = { [urls] url in
            Logger.tests.log("detection.onDidStart \(url?.absoluteString ?? "<nil>", privacy: .public)")
            XCTAssertEqual(url, urls.url2)
            onDetectionDidStart.fulfill()
        }
        let on2XXResponse = expectation(description: "on2XXResponse")
        detection.on2XXResponse = { [urls] url in
            Logger.tests.log("detection.on2XXResponse \(url?.absoluteString ?? "<nil>", privacy: .public)")
            XCTAssertEqual(url, urls.url2)
            on2XXResponse.fulfill()
        }
        let onNavigation = expectation(description: "onNavigation")
        logic.onNavigation = {
            Logger.tests.log("logic.onNavigation")
            onNavigation.fulfill()
        }

        let onDetectionDidFinish = expectation(description: "detection.onDidFinish")
        let onLogicDidFinish = expectation(description: "logic.onDidFinish")
        detection.onDidFinish = {
            Logger.tests.log("detection.onDidFinish \($0?.absoluteString ?? "<nil>", privacy: .public)")
            onDetectionDidFinish.fulfill()
        }
        logic.onDidFinish = { [now, urls] host, date in
            Logger.tests.log("logic.onDidFinish \(host ?? "<nil>", privacy: .public) \("\(date)", privacy: .public)")
            XCTAssertEqual(host, urls.url2.host!)
            XCTAssertEqual(date, now)
            onLogicDidFinish.fulfill()
        }

        Logger.tests.debug("➡️ setContent \(self.urls.url2.absoluteString, privacy: .public)")
        tab.setContent(.url(urls.url2, source: .link))
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testWhenNavigationRedirects_didFinishNotCalledForRedirectedNavigation() throws {
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        schemeHandler.middleware = [{ [data] request in
            guard request.url!.path == "/" else { return nil}
            Logger.tests.debug("schemeHandler.middleware #1 \(request.url?.absoluteString ?? "<nil>", privacy: .public)")
            return .ok(.html(data.metaRedirect.utf8String()!))
        }, { [data] request in
            Logger.tests.debug("schemeHandler.middleware #2 \(request.url?.absoluteString ?? "<nil>", privacy: .public)")
            return .ok(.html(data.html.utf8String()!))
        }]

        var onDetectionDidStart = expectation(description: "detection.onDidStart")
        let onDetectionDidStart2 = expectation(description: "detection.onDidStart 2")
        detection.onDidStart = { url in
            Logger.tests.log("detection.onDidStart \(url?.absoluteString ?? "<nil>", privacy: .public)")
            onDetectionDidStart.fulfill()
            onDetectionDidStart = onDetectionDidStart2
        }
        var on2XXResponse = expectation(description: "on2XXResponse")
        let on2XXResponse2 = expectation(description: "on2XXResponse 2")
        detection.on2XXResponse = { url in
            Logger.tests.log("detection.on2XXResponse \(url?.absoluteString ?? "<nil>", privacy: .public)")
            on2XXResponse.fulfill()
            on2XXResponse = on2XXResponse2
        }
        var onNavigation = expectation(description: "onNavigation")
        let onNavigation2 = expectation(description: "onNavigation 2")
        logic.onNavigation = {
            Logger.tests.log("logic.onNavigation")
            onNavigation.fulfill()
            onNavigation = onNavigation2
        }

        let onDetectionDidFinish = expectation(description: "detection.onDidFinish")
        let onLogicDidFinish = expectation(description: "logic.onDidFinish")
        detection.onDidFinish = {
            Logger.tests.log("detection.onDidFinish \($0?.absoluteString ?? "<nil>", privacy: .public)")
            onDetectionDidFinish.fulfill()
        }
        detection.onDidFail = {
            XCTFail("Not expected")
        }
        logic.onDidFinish = { [now, urls] host, date in
            Logger.tests.log("logic.onDidFinish \(host ?? "<nil>", privacy: .public) \("\(date)", privacy: .public)")
            XCTAssertEqual(host, urls.url2.host!)
            XCTAssertEqual(date, now)
            onLogicDidFinish.fulfill()
        }

        Logger.tests.debug("➡️ setContent \(self.urls.url1.absoluteString, privacy: .public)")
        tab.setContent(.url(urls.url1, source: .link))
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testWhenDeveloperRedirects_didFailNotCalledForRedirectedNavigation() throws {
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        // For first load, redirect from url1 to url2
        schemeHandler.middleware = [{ request in
            guard request.url!.path == "/" else { return nil}
            Logger.tests.debug("schemeHandler.middleware #1 \(request.url?.absoluteString ?? "<nil>", privacy: .public)")
            return .redirect(to: self.urls.url2)
        }, { [data] request in
            Logger.tests.debug("schemeHandler.middleware #1 \(request.url?.absoluteString ?? "<nil>", privacy: .public)")
            return .ok(.html(data.html.utf8String()!))
        }]

        // After redirect, issue developer redirect, that cancels url2 loading and navigates to url3
        decidePolicy = { navAction in
            if navAction.request.url == self.urls.url2 {
                Logger.tests.debug("decidePolicy \(navAction.url.absoluteString, privacy: .public) -> redirect to \(self.urls.url3.absoluteString, privacy: .public)")
                return .redirect(navAction.mainFrameTarget!, { navigator in
                    navigator.load(.init(url: self.urls.url3))
                })
            } else {
                Logger.tests.debug("decidePolicy \(navAction.url.absoluteString, privacy: .public) -> .next")
                return .next
            }
        }

        let onDetectionDidStart = expectation(description: "detection.onDidStart")
        onDetectionDidStart.assertForOverFulfill = false
        detection.onDidStart = { url in
            Logger.tests.log("detection.onDidStart \(url?.absoluteString ?? "<nil>", privacy: .public)")
            onDetectionDidStart.fulfill()
        }
        let on2XXResponse = expectation(description: "on2XXResponse")
        detection.on2XXResponse = { url in
            Logger.tests.log("detection.on2XXResponse \(url?.absoluteString ?? "<nil>", privacy: .public)")
            on2XXResponse.fulfill()
        }
        let onNavigation = expectation(description: "onNavigation")
        logic.onNavigation = {
            Logger.tests.log("logic.onNavigation")
            onNavigation.fulfill()
        }

        let onDetectionDidFinish = expectation(description: "detection.onDidFinish")
        let onLogicDidFinish = expectation(description: "logic.onDidFinish")
        detection.onDidFinish = {
            Logger.tests.log("detection.onDidFinish \($0?.absoluteString ?? "<nil>", privacy: .public)")
            onDetectionDidFinish.fulfill()
        }
        detection.onDidFail = {
            XCTFail("Not expected")
        }
        logic.onDidFinish = { [now, urls] host, date in
            Logger.tests.log("logic.onDidFinish \(host ?? "<nil>", privacy: .public) \("\(date)", privacy: .public)")
            XCTAssertEqual(host, urls.url3.host!)
            XCTAssertEqual(date, now)
            onLogicDidFinish.fulfill()
        }

        Logger.tests.debug("➡️ setContent \(self.urls.url1.absoluteString, privacy: .public)")
        tab.setContent(.url(urls.url1, source: .link))
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testWhenNavigationFails_eventsSent() {
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }
        schemeHandler.middleware = [{ request in
            Logger.tests.debug("schemeHandler.middleware #err \(request.url?.absoluteString ?? "<nil>", privacy: .public)")
            return .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost))
        }]
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        let onDetectionDidStart = expectation(description: "detection.onDidStart")
        detection.onDidStart = { [urls] url in
            Logger.tests.log("detection.onDidStart \(url?.absoluteString ?? "<nil>", privacy: .public)")
            XCTAssertEqual(url, urls.url2)
            onDetectionDidStart.fulfill()
        }

        let onDetectionDidFail = expectation(description: "detection.onDidFail")
        detection.onDidFail = {
            Logger.tests.log("detection.onDidFail")
            onDetectionDidFail.fulfill()
        }

        // skipping server.start
        Logger.tests.debug("➡️ setContent \(self.urls.url2.absoluteString, privacy: .public)")
        tab.setContent(.url(urls.url2, source: .link))
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testOnBackForward_onBackForwardNavigationCalled() throws {
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }
        let tab = Tab(content: .none, webViewConfiguration: webViewConfiguration, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        detection.onDidStart = { Logger.tests.log("detection.onDidStart \($0?.absoluteString ?? "<nil>", privacy: .public)") }
        detection.on2XXResponse = { Logger.tests.log("detection.on2XXResponse \($0?.absoluteString ?? "<nil>", privacy: .public)") }
        logic.onNavigation = { Logger.tests.log("logic.onNavigation") }
        detection.onDidFinish = { Logger.tests.log("detection.onDidFinish \($0?.absoluteString ?? "<nil>", privacy: .public)") }

        var onDidFinish = expectation(description: "onDidFinish 1")
        logic.onDidFinish = { host, time in
            Logger.tests.log("logic.onDidFinish \(host ?? "<nil>", privacy: .public) \("\(time)", privacy: .public)")
            onDidFinish.fulfill()
        }
        tab.setContent(.url(urls.url1, source: .link))
        waitForExpectations(timeout: 5)
        Logger.tests.debug("➡️ setContent \(self.urls.url1.absoluteString, privacy: .public)")

        onDidFinish = expectation(description: "onDidFinish 2")
        tab.setContent(.url(urls.url2, source: .link))
        waitForExpectations(timeout: 5)
        Logger.tests.debug("➡️ setContent \(self.urls.url2.absoluteString, privacy: .public)")

        detection.on2XXResponse = nil /*assert*/
        let onBackForward = expectation(description: "detection.onBackForward")
        logic.onBackForward = { [urls] url in
            XCTAssertEqual(url, urls.url1)
            Logger.tests.log("logic.onBackForward \(url?.absoluteString ?? "<nil>", privacy: .public)")
            onBackForward.fulfill()
        }
        let onDetectionDidStart = expectation(description: "detection.onDidStart")
        detection.onDidStart = { [urls] url in
            XCTAssertEqual(url, urls.url1)
            Logger.tests.log("detection.onDidStart \(url?.absoluteString ?? "<nil>", privacy: .public)")
            onDetectionDidStart.fulfill()
        }

        let onDetectionDidFinish = expectation(description: "detection.onDidFinish")
        let onLogicDidFinish = expectation(description: "logic.onDidFinish")
        detection.onDidFinish = {
            Logger.tests.log("detection.onDidFinish \($0?.absoluteString ?? "<nil>", privacy: .public)")
            onDetectionDidFinish.fulfill()
        }
        logic.onDidFinish = { [now, urls] host, date in
            Logger.tests.log("logic.onDidFinish \(host ?? "<nil>", privacy: .public) \("\(date)", privacy: .public)")
            XCTAssertEqual(host, urls.url1.host!)
            XCTAssertEqual(date, now)
            onLogicDidFinish.fulfill()
        }

        Logger.tests.debug("➡️ goBack()")
        tab.goBack()
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testOnLogicDidRequestRulesApplication_localContentRuleListIsInstalled() {
        privacyConfiguration.isFeatureKeyEnabled = { feature, _ in
            return feature == .contentBlocking
        }
        let userScriptInstalled = expectation(description: "userScriptInstalled")
        logic.onRulesChanged = { _ in
            userScriptInstalled.fulfill()
        }

        let tab = Tab(content: .none, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        waitForExpectations(timeout: 1)

        let castedLogic = withUnsafePointer(to: logic) { $0.withMemoryRebound(to: AdClickAttributionLogic.self, capacity: 1) { $0 } }.pointee

        let onDisableGlobalContentRuleList = expectation(description: "onDisableGlobalContentRuleList")
        userContentController.onDisableGlobalContentRuleList = { id in
            let globalListName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
            let globalAttributionListName = AdClickAttributionRulesSplitter.blockingAttributionRuleListName(forListNamed: globalListName)
            XCTAssertEqual(id, globalAttributionListName)
            onDisableGlobalContentRuleList.fulfill()
        }
        let ruleListMock = NSObject()
        let onInstallLocalContentRuleList = expectation(description: "onInstallLocalContentRuleList")
        userContentController.onInstallLocalContentRuleList = { ruleList, id in
            XCTAssertTrue(ruleList === ruleListMock)
            XCTAssertEqual(id, AdClickAttributionRulesProvider.Constants.attributedTempRuleListName)
            onInstallLocalContentRuleList.fulfill()
        }

        let ruleList = withUnsafePointer(to: ruleListMock) { $0.withMemoryRebound(to: WKContentRuleList.self, capacity: 1) { $0 } }.pointee
        logic.delegate!.attributionLogic(castedLogic, didRequestRuleApplication: .init(name: "rulesList", rulesList: ruleList, trackerData: .mock, encodedTrackerData: "etd", etag: "etag", identifier: .mock), forVendor: "vnd")

        waitForExpectations(timeout: 1)
        XCTAssertEqual(contentBlockerRulesScript.supplementaryTrackerData, [.mock])
        XCTAssertEqual(contentBlockerRulesScript.currentAdClickAttributionVendor, "vnd")

        withExtendedLifetime(tab) {}
    }

    @MainActor
    func testOnNilRulesApplication_supplementaryTrackerDataIsCleared() {
        privacyConfiguration.isFeatureKeyEnabled = { feature, _ in
            return feature == .contentBlocking
        }
        let userScriptInstalled = expectation(description: "userScriptInstalled")
        logic.onRulesChanged = { _ in
            userScriptInstalled.fulfill()
        }
        let tab = Tab(content: .none, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)

        let makeContentBlockerRulesCalled = expectation(description: "makeContentBlockerRulesCalled")
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
            makeContentBlockerRulesCalled.fulfill()
        }

        waitForExpectations(timeout: 1)

        let castedLogic = withUnsafePointer(to: logic) { $0.withMemoryRebound(to: AdClickAttributionLogic.self, capacity: 1) { $0 } }.pointee

        logic.delegate!.attributionLogic(castedLogic, didRequestRuleApplication: nil, forVendor: nil)
        XCTAssertEqual(contentBlockerRulesScript.supplementaryTrackerData, [])
        XCTAssertNil(contentBlockerRulesScript.currentAdClickAttributionVendor)

        withExtendedLifetime(tab) {}
    }

    @MainActor
    func testOnRulesApplicationWithContentBlockingDisabled_localContentRuleListIsRemoved() {
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }
        let userScriptInstalled = expectation(description: "userScriptInstalled")
        logic.onRulesChanged = { _ in
            userScriptInstalled.fulfill()
        }
        let tab = Tab(content: .none, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        waitForExpectations(timeout: 1)

        let castedLogic = withUnsafePointer(to: logic) { $0.withMemoryRebound(to: AdClickAttributionLogic.self, capacity: 1) { $0 } }.pointee

        let onRemoveLocalContentRuleList = expectation(description: "onRemoveLocalContentRuleList")
        userContentController.onRemoveLocalContentRuleList = { id in
            XCTAssertEqual(id, AdClickAttributionRulesProvider.Constants.attributedTempRuleListName)
            onRemoveLocalContentRuleList.fulfill()
        }
        logic.delegate!.attributionLogic(castedLogic, didRequestRuleApplication: nil, forVendor: nil)

        XCTAssertNil(contentBlockerRulesScript.currentAdClickAttributionVendor)
        XCTAssertEqual(contentBlockerRulesScript.supplementaryTrackerData, [])

        waitForExpectations(timeout: 1)
        withExtendedLifetime(tab) {}
    }

    @MainActor
    func testOnRulesApplicationWithNilVendor_localContentRuleListIsRemoved() {
        privacyConfiguration.isFeatureKeyEnabled = { feature, _ in
            return feature == .contentBlocking
        }
        let userScriptInstalled = expectation(description: "userScriptInstalled")
        logic.onRulesChanged = { _ in
            userScriptInstalled.fulfill()
        }
        let tab = Tab(content: .none, privacyFeatures: privacyFeaturesMock, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        waitForExpectations(timeout: 1)

        let castedLogic = withUnsafePointer(to: logic) { $0.withMemoryRebound(to: AdClickAttributionLogic.self, capacity: 1) { $0 } }.pointee

        let onRemoveLocalContentRuleList = expectation(description: "onRemoveLocalContentRuleList")
        userContentController.onRemoveLocalContentRuleList = { id in
            XCTAssertEqual(id, AdClickAttributionRulesProvider.Constants.attributedTempRuleListName)
            onRemoveLocalContentRuleList.fulfill()
        }
        let onEnableGlobalContentRuleList = expectation(description: "onEnableGlobalContentRuleList")
        userContentController.onEnableGlobalContentRuleList = { id in
            let globalListName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
            let globalAttributionListName = AdClickAttributionRulesSplitter.blockingAttributionRuleListName(forListNamed: globalListName)
            XCTAssertEqual(id, globalAttributionListName)
            onEnableGlobalContentRuleList.fulfill()
        }

        let ruleListMock = NSObject()
        let ruleList = withUnsafePointer(to: ruleListMock) { $0.withMemoryRebound(to: WKContentRuleList.self, capacity: 1) { $0 } }.pointee
        logic.delegate!.attributionLogic(castedLogic, didRequestRuleApplication: .init(name: "rulesList", rulesList: ruleList, trackerData: .mock, encodedTrackerData: "etd", etag: "etag", identifier: .mock), forVendor: nil)

        XCTAssertNil(contentBlockerRulesScript.currentAdClickAttributionVendor)
        XCTAssertEqual(contentBlockerRulesScript.supplementaryTrackerData, [.mock])

        waitForExpectations(timeout: 1)
        withExtendedLifetime(tab) {}
    }

    @MainActor
    func testOnTrackerDataupdated_onRequestDetectedIsCalled() {
        let tab = Tab(content: .none, extensionsBuilder: extensionsBuilder, shouldLoadInBackground: true)
        DispatchQueue.main.async {
            self.makeContentBlockerRulesUserScript()
        }

        let mockRequest = DetectedRequest(url: "testurl.com", eTLDplus1: nil, knownTracker: nil, entity: .init(displayName: "entity", domains: nil, prevalence: 1), state: .blocked, pageUrl: "pageurl.com")
        let onRequestDetected = expectation(description: "onRequestDetected")
        logic.onRequestDetected = { request in
            XCTAssertEqual(request, mockRequest)
            onRequestDetected.fulfill()
        }

        DispatchQueue.main.async {
            self.trackerInfoPublisher.send(mockRequest)
        }

        waitForExpectations(timeout: 1)
        withExtendedLifetime(tab) {}
    }

}

class MockAdClickLogic: AdClickLogicProtocol {

    var state: BrowserServicesKit.AdClickAttributionLogic.State = .noAttribution
    weak var delegate: BrowserServicesKit.AdClickAttributionLogicDelegate?

    var onApplyInheritedAttribution: ((AdClickAttributionLogic.State?) -> Void)!
    func applyInheritedAttribution(state: AdClickAttributionLogic.State?) {
        onApplyInheritedAttribution(state)

        let castedLogic = withUnsafePointer(to: self) { $0.withMemoryRebound(to: AdClickAttributionLogic.self, capacity: 1) { $0 } }.pointee
        let ruleListMock = NSObject()
        let ruleList = withUnsafePointer(to: ruleListMock) { $0.withMemoryRebound(to: WKContentRuleList.self, capacity: 1) { $0 } }.pointee
        self.delegate!.attributionLogic(castedLogic, didRequestRuleApplication: .init(name: "rulesList", rulesList: ruleList, trackerData: .mock, encodedTrackerData: "etd", etag: "etag", identifier: .mock), forVendor: "vnd")
    }

    var debugID = "test"

    var onRulesChanged: (([ContentBlockerRulesManager.Rules]) -> Void)?
    func onRulesChanged(latestRules: [ContentBlockerRulesManager.Rules]) {
        onRulesChanged?(latestRules)
    }

    var onRequestDetected: ((DetectedRequest) -> Void)!
    func onRequestDetected(request: DetectedRequest) {
        onRequestDetected(request)
    }

    var onBackForward: ((URL?) -> Void)!
    func onBackForwardNavigation(mainFrameURL: URL?) {
        onBackForward(mainFrameURL)
    }

    var onNavigation: (() -> Void)!
    func onProvisionalNavigation() async {
        onNavigation()
    }

    var onDidFinish: ((String?, Date) -> Void)!
    func onDidFinishNavigation(host: String?, currentTime: Date) {
        onDidFinish(host, currentTime)
    }

}
class MockAdClickDetection: AdClickAttributionDetecting {

    var onDidStart: ((URL?) -> Void)!
    func onStartNavigation(url: URL?) {
        onDidStart(url)
    }

    var on2XXResponse: ((URL?) -> Void)!
    func on2XXResponse(url: URL?) {
        on2XXResponse(url)
    }

    var onDidFinish: ((URL?) -> Void)!
    func onDidFinishNavigation(url: URL?) {
        onDidFinish(url)
    }

    var onDidFail: (() -> Void)!
    func onDidFailNavigation() {
        onDidFail()
    }

}

class MockContentBlockerRulesUserScript: ContentBlockerScriptProtocol {
    var currentAdClickAttributionVendor: String? = "vendor"

    var supplementaryTrackerData = [TrackerData.empty]

}

extension TrackerData {
    static let empty = TrackerData(trackers: [:], entities: [:], domains: [:], cnames: nil)
    static let mock = TrackerData(trackers: [:], entities: [:], domains: ["test": "test"], cnames: nil)

}
extension ContentBlockerRulesIdentifier {
    static let mock = ContentBlockerRulesIdentifier(name: "name", tdsEtag: "tdsEtag", tempListId: nil, allowListId: nil, unprotectedSitesHash: nil)
}

class UserContentControllerMock: UserContentControllerProtocol {
    var contentBlockingAssetsInstalled: Bool { true }

    var onEnableGlobalContentRuleList: ((String) -> Void)!
    func enableGlobalContentRuleList(withIdentifier identifier: String) throws {
        onEnableGlobalContentRuleList(identifier)
    }

    var onDisableGlobalContentRuleList: ((String) -> Void)!
    func disableGlobalContentRuleList(withIdentifier identifier: String) throws {
        onDisableGlobalContentRuleList(identifier)
    }

    var onRemoveLocalContentRuleList: ((String) -> Void)!
    func removeLocalContentRuleList(withIdentifier identifier: String) {
        onRemoveLocalContentRuleList(identifier)
    }

    var onInstallLocalContentRuleList: ((WKContentRuleList, String) -> Void)!
    func installLocalContentRuleList(_ ruleList: WKContentRuleList, identifier: String) {
        onInstallLocalContentRuleList(ruleList, identifier)
    }

}

extension AdClickAttributionLogic.State: Equatable {
    public static func == (lhs: BrowserServicesKit.AdClickAttributionLogic.State, rhs: BrowserServicesKit.AdClickAttributionLogic.State) -> Bool {
        switch lhs {
        case .noAttribution: if case .noAttribution = rhs { return true }
        case .activeAttribution(vendor: let vendor, session: let session, rules: let rules):
            if case .activeAttribution(vendor: vendor, session: session, rules: rules) = rhs { return true }
        case .preparingAttribution(vendor: let vendor, session: let session, let id, completionBlocks: _):
            if case .preparingAttribution(vendor: vendor, session: session, requestID: id, completionBlocks: _) = rhs { return true }
        }
        return false
    }
}
extension AdClickAttributionLogic.SessionInfo: Equatable {
    public static func == (lhs: AdClickAttributionLogic.SessionInfo, rhs: AdClickAttributionLogic.SessionInfo) -> Bool {
        lhs.attributionStartedAt == rhs.attributionStartedAt && lhs.leftAttributionContextAt == rhs.leftAttributionContextAt
    }
}
extension ContentBlockerRulesManager.Rules: Equatable {
    public static func == (lhs: ContentBlockerRulesManager.Rules, rhs: ContentBlockerRulesManager.Rules) -> Bool {
        lhs.identifier == rhs.identifier && lhs.encodedTrackerData == rhs.encodedTrackerData && lhs.etag == rhs.etag
            && lhs.name == rhs.name && lhs.rulesList === rhs.rulesList && lhs.trackerData == rhs.trackerData
    }
}
