//
//  NewTabPageCustomizerOpener.swift
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
import WebKit

/**
 * This small class exposes an interface that allows for triggering
 * events that should open New Tab Page settings.
 *
 * It's a requirement in `NewTabPageCustomBackgroundProviding` protocol
 * and must be provided by classes implementing that protocol on the client app side.
 * `NewTabPageCustomBackgroundClient` connects to the opener and forwards
 * open settings requests to the JS side.
 */
public final class NewTabPageCustomizerOpener {
    public init() {
        openSettingsPublisher = openSettingsSubject.eraseToAnyPublisher()
    }

    public func openSettings(for webView: WKWebView) {
        openSettingsSubject.send(webView)
    }

    let openSettingsPublisher: AnyPublisher<WKWebView, Never>
    private let openSettingsSubject = PassthroughSubject<WKWebView, Never>()
}
