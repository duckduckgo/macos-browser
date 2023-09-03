//
//  PrivacyDebugToolsTabExtension.swift
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

import Combine
import Common
import Foundation
import Navigation

protocol PrivacyDebugToolsScriptsProvider {
    var privacyConfigurationEditUserScript: PrivacyConfigurationEditUserScript? { get }
}
extension UserScripts: PrivacyDebugToolsScriptsProvider {}

final class PrivacyDebugToolsTabExtension {

    let privacyDebugTools: PrivacyDebugTools
    let trackersPublisher: AnyPublisher<DetectedTracker, Never>
    private var cancellables = Set<AnyCancellable>()
    private weak var privacyConfigurationEditUserScript: PrivacyConfigurationEditUserScript?

    private weak var webView: WKWebView? {
        didSet {
            privacyConfigurationEditUserScript?.webView = webView
        }
    }

    init(
        privacyDebugTools: PrivacyDebugTools,
        scriptsPublisher: some Publisher<some PrivacyDebugToolsScriptsProvider, Never>,
        webViewPublisher: some Publisher<WKWebView, Never>,
        trackersPublisher: some Publisher<DetectedTracker, Never>
    ) {
        self.privacyDebugTools = privacyDebugTools
        self.trackersPublisher = trackersPublisher as! AnyPublisher<DetectedTracker, Never>

        scriptsPublisher
            .sink { [weak self] scripts in
                self?.privacyConfigurationEditUserScript = scripts.privacyConfigurationEditUserScript
                self?.privacyConfigurationEditUserScript?.debugTools = self?.privacyDebugTools
                self?.privacyConfigurationEditUserScript?.webView = self?.webView
            }
            .store(in: &cancellables)

        webViewPublisher
            .sink { [weak self] webView in
                self?.webView = webView
            }
            .store(in: &cancellables)

        self.trackersPublisher
            .sink { [weak self] tracker in
                guard let self else { return }
                self.privacyDebugTools.tracker(tracker: tracker)
            }
            .store(in: &cancellables)
    }
}

extension PrivacyDebugToolsTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard privacyDebugTools.isEnabled else {
            return .next
        }
        // Always allow loading Privacy Debug Tools URLs (from CCF)
        privacyConfigurationEditUserScript?.isActive = navigationAction.url.isPrivacyDebugTools
        if privacyConfigurationEditUserScript?.isActive == true {
            return .allow
        }
        return .next
    }
}

protocol PrivacyDebugToolsTabExtensionProtocol: AnyObject, NavigationResponder {
}

extension PrivacyDebugToolsTabExtension: PrivacyDebugToolsTabExtensionProtocol, TabExtension {
    func getPublicProtocol() -> PrivacyDebugToolsTabExtensionProtocol { self }
}

extension TabExtensions {
    var privacyDebugTools: PrivacyDebugToolsTabExtensionProtocol? { resolve(PrivacyDebugToolsTabExtension.self) }
}
