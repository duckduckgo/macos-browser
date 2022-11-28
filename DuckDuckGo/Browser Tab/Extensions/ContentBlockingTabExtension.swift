//
//  ContentBlockingTabExtension.swift
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

import BrowserServicesKit
import Combine
import Foundation

typealias DetectedTracker = (tracker: DetectedRequest, surrogateHost: String?)
final class ContentBlockingTabExtension: NSObject, TabExtension {

    @Injected(default: .shared) static var cbaTimeReporter: ContentBlockingAssetsCompilationTimeReporter?

    private weak var tab: Tab?
    private var tabIdentifier: UInt64?
    private var userScriptsCancellable: AnyCancellable?
    fileprivate var detectedTrackersSubject = PassthroughSubject<DetectedTracker, Never>()

    // MARK: - Dashboard Info

    @Published private(set) var trackerInfo: TrackerInfo?
    @Published private(set) var serverTrust: ServerTrust?
    @Published private(set) var cookieConsentManaged: CookieConsentInfo?

    override init() {
        super.init()
    }
    
    func attach(to tab: Tab) {
        self.tab = tab

        userScriptsCancellable = tab.userScriptsPublisher.sink { [weak self] userScripts in
            self?.tabIdentifier = self?.tab?.extensions.instrumentation.currentTabIdentifier

            userScripts?.surrogatesScript.delegate = self
            userScripts?.contentBlockerRulesScript.delegate = self
            if #available(macOS 11, *) {
                userScripts?.autoconsentUserScript?.delegate = self
            }
        }
    }

    private func resetDashboardInfo() {
        trackerInfo = TrackerInfo()
        if self.serverTrust?.host != tab?.content.url?.host {
            serverTrust = nil
        }
    }

    deinit {
        if let cbaTimeReporter = Self.cbaTimeReporter,
           let tabIdentifier = tabIdentifier {

            cbaTimeReporter.tabWillClose(tabIdentifier)
        }
    }

}

extension ContentBlockingTabExtension: ContentBlockerRulesUserScriptDelegate {

    func contentBlockerRulesUserScriptShouldProcessTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return true
    }

    func contentBlockerRulesUserScriptShouldProcessCTLTrackers(_ script: ContentBlockerRulesUserScript) -> Bool {
        return tab?.extensions.clickToLoad?.fbBlockingEnabled == true
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedTracker tracker: DetectedRequest) {
        trackerInfo?.add(detectedTracker: tracker)
        detectedTrackersSubject.send( (tracker, nil) )
    }

    func contentBlockerRulesUserScript(_ script: ContentBlockerRulesUserScript, detectedThirdPartyRequest request: DetectedRequest) {
        trackerInfo?.add(detectedThirdPartyRequest: request)
    }

}

extension ContentBlocking {

    func entityName(forDomain domain: String) -> String? {
        var entityName: String?
        var parts = domain.components(separatedBy: ".")
        while parts.count > 1 && entityName == nil {
            let host = parts.joined(separator: ".")
            entityName = trackerDataManager.trackerData.domains[host]
            parts.removeFirst()
        }
        return entityName
    }

}

extension ContentBlockingTabExtension: SurrogatesUserScriptDelegate {

    func surrogatesUserScriptShouldProcessTrackers(_ script: SurrogatesUserScript) -> Bool {
        return true
    }

    func surrogatesUserScript(_ script: SurrogatesUserScript, detectedTracker tracker: DetectedRequest, withSurrogate host: String) {
        trackerInfo?.add(installedSurrogateHost: host)
        trackerInfo?.add(detectedTracker: tracker)
        detectedTrackersSubject.send( (tracker, host) )
    }

}

@available(macOS 11, *)
extension ContentBlockingTabExtension: AutoconsentUserScriptDelegate {

    func autoconsentUserScript(consentStatus: CookieConsentInfo) {
        self.cookieConsentManaged = consentStatus
    }

    func autoconsentUserScriptPromptUserForConsent(_ result: @escaping (Bool) -> Void) {
        tab?.delegate?.tab(tab!, promptUserForCookieConsent: result)
    }

}

extension ContentBlockingTabExtension: NavigationResponder {

    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        // Ensure Content Blocking Assets (WKContentRuleList&UserScripts) are installed
        if tab?.userContentController.contentBlockingAssetsInstalled == false, let tabIdentifier = tabIdentifier {
            Self.cbaTimeReporter?.tabWillWaitForRulesCompilation(tabIdentifier)
            await tab?.userContentController.awaitContentBlockingAssetsInstalled()
            Self.cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(tabIdentifier)
        } else {
            Self.cbaTimeReporter?.reportNavigationDidNotWaitForRules()
        }
        return .next
    }

    func webView(_ webView: WebView, didStart navigation: WKNavigation, with request: URLRequest) {
        resetDashboardInfo()
    }

}

extension Tab {

    var trackerInfo: TrackerInfo? {
        extensions.contentBlocking?.trackerInfo
    }
    var trackerInfoPublisher: AnyPublisher<TrackerInfo?, Never> {
        extensions.contentBlocking?.$trackerInfo.eraseToAnyPublisher() ?? Just(nil).eraseToAnyPublisher()
    }
    var detectedTrackersPublisher: AnyPublisher<DetectedTracker, Never> {
        extensions.contentBlocking?.detectedTrackersSubject.eraseToAnyPublisher() ?? PassthroughSubject().eraseToAnyPublisher()
    }

    var serverTrustPublisher: AnyPublisher<ServerTrust?, Never> {
        extensions.contentBlocking?.$serverTrust.eraseToAnyPublisher() ?? Just(nil).eraseToAnyPublisher()
    }

    var cookieConsentManagedPublisher: AnyPublisher<CookieConsentInfo?, Never> {
        extensions.contentBlocking?.$cookieConsentManaged.eraseToAnyPublisher() ?? Just(nil).eraseToAnyPublisher()
    }

}
