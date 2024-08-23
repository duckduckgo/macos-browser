//
//  DuckPlayerOnboardingTabExtension.swift
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

import Foundation
import Navigation
import Combine

typealias DuckPlayerOnboardingPublisher = AnyPublisher<OnboardingState?, Never>

final class DuckPlayerOnboardingTabExtension: TabExtension {
    @Published private(set) var onboardingState: OnboardingState?
    private let onboardingDecider: DuckPlayerOnboardingDecider

    init(onboardingDecider: DuckPlayerOnboardingDecider = DefaultDuckPlayerOnboardingDecider()) {
        self.onboardingDecider = onboardingDecider
    }
}

extension DuckPlayerOnboardingTabExtension: NavigationResponder {

    func navigationDidFinish(_ navigation: Navigation) {
        guard onboardingDecider.canDisplayOnboarding else { return }
        
        let locationValidator = DuckPlayerOnboardingLocationValidator()

        Task { @MainActor in
            if await locationValidator.isValidLocation(navigation) {
                onboardingState = .init(onboardingDecider: onboardingDecider)
            }
        }
    }
}

struct DuckPlayerOnboardingLocationValidator {
    private static let youtubeChannelCheckScript = """
        (function() {
            var canonicalLink = document.querySelector('link[rel="canonical"]');
            return canonicalLink && canonicalLink.href.includes('channel');
        })();
    """

    func isValidLocation(_ navigation: Navigation) async -> Bool {
        guard let webView = await navigation.navigationAction.targetFrame?.webView,
              let url = await webView.url else { return false }

        let isRootURL = isYoutubeRootURL(url)
        let isInChannel = await isCurrentWebViewInAYoutubeChannel(webView)
        return isRootURL || isInChannel
    }

    private func isYoutubeRootURL(_ url: URL) -> Bool {
        guard let urlComponents = URLComponents(string: url.absoluteString) else { return false }
        return urlComponents.scheme == "https" &&
               urlComponents.host == "www.youtube.com" &&
               urlComponents.path == "/"
    }

    private func isCurrentWebViewInAYoutubeChannel(_ webView: WKWebView) async -> Bool {
        do {
            return try await webView.evaluateJavaScript(DuckPlayerOnboardingLocationValidator.youtubeChannelCheckScript) as Bool? ?? false
        } catch {
            return false
        }
    }
}

struct OnboardingState {
    let onboardingDecider: DuckPlayerOnboardingDecider
}

protocol DuckPlayerOnboardingProtocol: AnyObject, NavigationResponder {
    var duckPlayerOnboardingPublisher: DuckPlayerOnboardingPublisher  { get }
}

extension DuckPlayerOnboardingTabExtension: DuckPlayerOnboardingProtocol {
    func getPublicProtocol() -> DuckPlayerOnboardingProtocol { self }

    var duckPlayerOnboardingPublisher: DuckPlayerOnboardingPublisher {
        self.$onboardingState.eraseToAnyPublisher()
    }
}

extension TabExtensions {
    var duckPlayerOnboarding: DuckPlayerOnboardingProtocol? {
        resolve(DuckPlayerOnboardingTabExtension.self)
    }
}

extension Tab {
    var duckPlayerOnboardingPublisher:DuckPlayerOnboardingPublisher {
        self.duckPlayerOnboarding?.duckPlayerOnboardingPublisher ?? Just(nil).eraseToAnyPublisher()
    }
}
