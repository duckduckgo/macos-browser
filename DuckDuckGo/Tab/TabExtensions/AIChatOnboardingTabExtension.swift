//
//  AIChatOnboardingTabExtension.swift
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

import Navigation
import Foundation
import Combine
import WebKit

final class AIChatOnboardingTabExtension {
    private weak var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter: NotificationCenter
    private let remoteSettings: AIChatRemoteSettingsProvider

    init(webViewPublisher: some Publisher<WKWebView, Never>,
         notificationCenter: NotificationCenter,
         remoteSettings: AIChatRemoteSettingsProvider) {

        self.notificationCenter = notificationCenter
        self.remoteSettings = remoteSettings

        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView
        }.store(in: &cancellables)
    }

    private func validateAIChatCookie(webView: WKWebView) {
        guard let url = webView.url,
              url.isDuckDuckGo,
              isQueryItemEqualToDuckDuckGoAIChat(url: url) else {
            return
        }

        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore

        cookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            if cookies.contains(where: { $0.isAIChatCookie(settings: self.remoteSettings) }) {
                self.notificationCenter.post(name: .AIChatOpenedForReturningUser, object: nil)
            }
        }
    }

    private func isQueryItemEqualToDuckDuckGoAIChat(url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let queryItems = components?.queryItems {
            if let queryValue = queryItems.first(where: { $0.name == remoteSettings.aiChatURLIdentifiableQuery })?.value {
                return queryValue == remoteSettings.aiChatURLIdentifiableQueryValue
            }
        }

        return false
    }
}

extension AIChatOnboardingTabExtension: NavigationResponder {
    @MainActor func navigationDidFinish(_ navigation: Navigation) {
        guard let webView = webView else { return }
        validateAIChatCookie(webView: webView)
    }

    func navigation(_ navigation: Navigation, didSameDocumentNavigationOf navigationType: WKSameDocumentNavigationType) {
        guard let webView = webView else { return }
        validateAIChatCookie(webView: webView)
    }
}

protocol AIChatOnboardingProtocol: AnyObject, NavigationResponder {
}

extension AIChatOnboardingTabExtension: AIChatOnboardingProtocol, TabExtension {
    func getPublicProtocol() -> AIChatOnboardingProtocol { self }
}

extension TabExtensions {
    var aiChatOnboarding: AIChatOnboardingProtocol? {
        resolve(AIChatOnboardingTabExtension.self)
    }
}

private extension HTTPCookie {
    func isAIChatCookie(settings: AIChatRemoteSettingsProvider) -> Bool {
        name == settings.onboardingCookieName && domain == settings.onboardingCookieDomain
    }
}

extension NSNotification.Name {
    static let AIChatOpenedForReturningUser = NSNotification.Name("aichat.AIChatOpenedForReturningUser")
}
