//
//  ReaderModeTabExtension.swift
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
import WebKit

final class ReaderModeTabExtension {

    @Published private(set) var readerModeState: ReaderModeState = .unavailable
    private weak var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()
    private var expectingResultForUrl: URL?

    init(userScriptPublisher: some Publisher<ReaderModeUserScript, Never>,
         webViewPublisher: some Publisher<WKWebView, Never>) {

        userScriptPublisher.sink { [weak self] userScript in
            self?.subscribeToUserScript(userScript: userScript)
        }.store(in: &cancellables)
        webViewPublisher.map { $0 }
            .assign(to: \.webView, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToUserScript(userScript: ReaderModeUserScript) {
        userScript.delegate = self
    }

    func activateReaderMode() {
        guard case .available = readerModeState else {
            assertionFailure("ReaderMode unavailable")
            return
        }
        guard let url = webView?.url else {
            assertionFailure("URL not set")
            return
        }

        if (try? ReaderModeCache.shared.readabilityResult(for: url)) == nil {
            expectingResultForUrl = url
        } else {
            webView?.load(URLRequest(url: URL.readerUrl.appendingParameter(name: "url", value: url.absoluteString)))
        }
    }

}

extension ReaderModeTabExtension: ReaderModeUserScriptDelegate {

    func readerMode(_ readerScript: ReaderModeUserScript, didChangeReaderModeState state: ReaderModeState) {
        readerModeState = state
    }

    func readerModeDidDisplayReaderizedContentForTab(_ readerScript: ReaderModeUserScript) {
        readerModeState = .active
    }

    func readerMode(_ readerScript: ReaderModeUserScript, didParseReadabilityResult readabilityResult: ReadabilityResult) {
        guard let url = webView?.url else { return }
        ReaderModeCache.shared.cacheReadabilityResult(readabilityResult, for: url)
        if expectingResultForUrl == url {
            activateReaderMode()
        }
    }

}

extension ReaderModeTabExtension: NavigationResponder {

    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard navigationAction.isForMainFrame else { return .next }
        expectingResultForUrl = nil

        if navigationAction.url.scheme == ReaderModeSchemeHandler.readerModeScheme,
           let url = navigationAction.url.getParameter(named: "url").flatMap(URL.init(string:)),
           url == navigationAction.targetFrame?.url
            || navigationAction.navigationType.isBackForward
            || navigationAction.navigationType.isSessionRestoration
            || navigationAction.navigationType == .reload {

            return .allow
        }
        return .next
    }

    func navigationDidFinish(_ navigation: Navigation) {
        let js = "\(ReaderModeNamespace).checkReadability()"
        if #available(macOS 11.0, *) {
            webView?.evaluateJavaScript(js, in: nil, in: WKContentWorld.defaultClient)
        } else {
            webView?.evaluateJavaScript(js)
        }
    }

}

protocol ReaderModeTabExtensionProtocol: AnyObject, NavigationResponder {
    var readerModeStatePublisher: AnyPublisher<ReaderModeState, Never> { get }

    func activateReaderMode()
}

extension ReaderModeTabExtension: TabExtension, ReaderModeTabExtensionProtocol {
    func getPublicProtocol() -> ReaderModeTabExtensionProtocol {
        self
    }

    var readerModeStatePublisher: AnyPublisher<ReaderModeState, Never> {
        $readerModeState.eraseToAnyPublisher()
    }

}

extension TabExtensions {
    var readerMode: ReaderModeTabExtensionProtocol? {
        resolve(ReaderModeTabExtension.self)
    }
}
