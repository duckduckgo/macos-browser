//
//  LazyLoadable.swift
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

import Combine
import Foundation
import Navigation

protocol LazyLoadable: AnyObject, Identifiable {

    var isUrl: Bool { get }
    var url: URL? { get }

    var webViewSize: CGSize { get set }
    var isLazyLoadingInProgress: Bool { get set }
    var loadingFinishedPublisher: AnyPublisher<Self, Never> { get }

    @discardableResult
    func reload() -> ExpectedNavigation?
    func isNewer(than other: Self) -> Bool
}

extension Tab: LazyLoadable {
    var isUrl: Bool { content.isUrl }

    var url: URL? { content.urlForWebView }

    var loadingFinishedPublisher: AnyPublisher<Tab, Never> {
        navigationStatePublisher.compactMap { $0 }
            .filter { $0.isCompleted }
            .prefix(1)
            .map { _ in self }
            .eraseToAnyPublisher()
    }

    var webViewSize: CGSize {
        get { webView.frame.size }
        set { webView.frame.size = newValue }
    }

    func isNewer(than other: Tab) -> Bool {
        switch (lastSelectedAt, other.lastSelectedAt) {
        case (.none, .none), (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.some(let timestamp), .some(let otherTimestamp)):
            return timestamp > otherTimestamp
        }
    }
}
