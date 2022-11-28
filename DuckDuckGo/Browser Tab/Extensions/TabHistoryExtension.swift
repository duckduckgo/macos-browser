//
//  TabHistoryExtension.swift
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

final class TabHistoryExtension: TabExtension {

    @Injected(default: HistoryCoordinator.shared, .testable) static var historyCoordinating: HistoryCoordinating

    private weak var tab: Tab?
    private var lastURL: URL? {
        didSet {
            if let oldUrl = oldValue {
                Self.historyCoordinating.commitChanges(url: oldUrl)
            }
        }
    }
    private var cancellables = Set<AnyCancellable>()

    init() {}

    func attach(to tab: Tab) {
        self.tab = tab

        tab.$content
            .map {
                $0.isUrl ? $0.url : nil
            }
            .assign(to: \.lastURL, onWeaklyHeld: self)
            .store(in: &cancellables)

        tab.detectedTrackersPublisher
            .sink { [weak tab] (tracker, surrogateHost) in
                guard let url = {
                    if surrogateHost == nil {
                        return tab?.webView.url
                    } else {
                        return URL.init(string: tracker.pageUrl)
                    }
                }() else { return }

                Self.historyCoordinating.addDetectedTracker(tracker, onURL: url)
            }
            .store(in: &cancellables)
    }

    private enum NSSecureCodingKeys {
        static let visitedDomains = "visitedDomains"
    }
    func awakeAfter(using decoder: NSCoder) {
        let visitedDomains = decoder.decodeObject(of: [NSArray.self, NSString.self], forKey: NSSecureCodingKeys.visitedDomains) as? [String] ?? []
        self.localHistory = Set(visitedDomains)
    }
    func encode(using coder: NSCoder) {
        coder.encode(Array(localHistory), forKey: NSSecureCodingKeys.visitedDomains)
    }

    deinit {
        if let url = lastURL {
            Self.historyCoordinating.commitChanges(url: url)
        }
    }

    private var shouldStoreNextVisit = true
    var localHistory = Set<String>()

    func addVisit(of url: URL) {
        guard shouldStoreNextVisit else {
            shouldStoreNextVisit = true
            return
        }

        // Add to global history
        Self.historyCoordinating.addVisit(of: url)

        // Add to local history
        if let host = url.host, !host.isEmpty {
            localHistory.insert(host.droppingWwwPrefix())
        }
    }

    func updateVisitTitle(_ title: String, url: URL) {
        Self.historyCoordinating.updateTitleIfNeeded(title: title, url: url)
    }

}

extension TabHistoryExtension: NavigationResponder {

    func webView(_ webView: WebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool) {
        shouldStoreNextVisit = false
    }

    func webView(_ webView: WebView, didCommit navigation: WKNavigation, with request: URLRequest) {
        if tab?.content.isUrl == true, let url = request.url {
            addVisit(of: url)
        }
    }

    func webView(_ webView: WebView, didFinish navigation: WKNavigation, with request: URLRequest) {
        StatisticsLoader.shared.refreshRetentionAtb(isSearch: request.url?.isDuckDuckGoSearch == true)
    }

    func webView(_ webView: WebView, navigation: WKNavigation, with request: URLRequest, didFailWith error: Error) {
        switch error {
        case URLError.notConnectedToInternet,
             URLError.networkConnectionLost:

            guard let failingUrl = error.failingUrl else { break }
            Self.historyCoordinating.markFailedToLoadUrl(failingUrl)
        default:
            break
        }
    }

}

extension Tab {

    var localHistory: Set<String> {
        extensions.history?.localHistory ?? []
    }

}

extension HistoryCoordinating {

    func addDetectedTracker(_ tracker: DetectedRequest, onURL url: URL) {
        trackerFound(on: url)

        guard tracker.isBlocked,
              let entityName = tracker.entityName else { return }

        addBlockedTracker(entityName: entityName, on: url)
    }

}
