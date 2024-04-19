//
//  BrokenSiteInfoTabExtension.swift
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

import BrowserServicesKit
import Combine
import Foundation
import Navigation
import PrivacyDashboard
import UserScript

final class BrokenSiteInfoTabExtension {

    private(set) var lastWebError: Error?
    private(set) var lastHttpStatusCode: Int?

    private(set) var inferredOpenerContext: BrokenSiteReport.OpenerContext?
    private(set) var refreshCountSinceLoad: Int = 0

    private(set) var performanceMetrics: PerformanceMetricsSubfeature?

    private var cancellables = Set<AnyCancellable>()

    init(contentPublisher: some Publisher<Tab.TabContent, Never>,
         webViewPublisher: some Publisher<WKWebView, Never>,
         contentScopeUserScriptPublisher: some Publisher<ContentScopeUserScript, Never>) {

        webViewPublisher.sink { [weak self] webView in
            self?.performanceMetrics = PerformanceMetricsSubfeature(targetWebview: webView)
        }.store(in: &cancellables)

        contentScopeUserScriptPublisher.sink { [weak self] contentScopeUserScript in
            guard let self, let performanceMetrics else { return }
            contentScopeUserScript.registerSubfeature(delegate: performanceMetrics)
        }.store(in: &cancellables)
    }

    private func resetRefreshCountIfNeeded(action: NavigationAction) {
        switch action.navigationType {
        case .reload, .other:
            break
        default:
            refreshCountSinceLoad = 0
        }
    }

    private func setOpenerContextIfNeeded(action: NavigationAction) {
        switch action.navigationType {
        case .linkActivated, .formSubmitted:
            inferredOpenerContext = .navigation
        default:
            break
        }
    }

    func tabReloadRequested() {
        refreshCountSinceLoad += 1
    }

}

extension BrokenSiteInfoTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        resetRefreshCountIfNeeded(action: navigationAction)
        setOpenerContextIfNeeded(action: navigationAction)

        return .next
    }

    @MainActor
    func willStart(_ navigation: Navigation) {
        if lastWebError != nil { lastWebError = nil }
    }

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        lastHttpStatusCode = navigationResponse.httpStatusCode

        return .next
    }

    @MainActor
    func didStart(_ navigation: Navigation) {
        if inferredOpenerContext != .external {
            inferredOpenerContext = nil
        }

        if lastWebError != nil {
            lastWebError = nil
        }
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        Task { @MainActor in
            if await navigation.navigationAction.targetFrame?.webView?.isCurrentSiteReferredFromDuckDuckGo == true {
                inferredOpenerContext = .serp
            }
        }
    }

    @MainActor
    func didFailProvisionalLoad(with request: URLRequest, in frame: WKFrameInfo, with error: Error) {
        lastWebError = error
    }

}

protocol BrokenSiteInfoTabExtensionProtocol: AnyObject, NavigationResponder {
    var lastWebError: Error? { get }
    var lastHttpStatusCode: Int? { get }

    var inferredOpenerContext: BrokenSiteReport.OpenerContext? { get }
    var refreshCountSinceLoad: Int { get }

    var performanceMetrics: PerformanceMetricsSubfeature? { get }

    func tabReloadRequested()
}

extension BrokenSiteInfoTabExtension: TabExtension, BrokenSiteInfoTabExtensionProtocol {
    typealias PublicProtocol = BrokenSiteInfoTabExtensionProtocol
    func getPublicProtocol() -> PublicProtocol { self }
}

extension TabExtensions {
    var brokenSiteInfo: BrokenSiteInfoTabExtensionProtocol? {
        resolve(BrokenSiteInfoTabExtension.self)
    }
}
