//
//  HistoryTabExtension.swift
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
import Common
import ContentBlocking
import Foundation
import Navigation

final class HistoryTabExtension: NSObject {

    private let historyCoordinating: HistoryCoordinating
    private let isBurner: Bool

    private(set) var localHistory = Set<String>()
    private var cancellables = Set<AnyCancellable>()

    private var url: URL? {
        willSet {
            guard let oldValue = url else { return }
            historyCoordinating.commitChanges(url: oldValue)
        }
        didSet {
            visitState = .expected
        }
    }

    private enum VisitState {
        case expected
        case added
    }
    private var visitState: VisitState = .expected

    init(isBurner: Bool,
         historyCoordinating: HistoryCoordinating,
         trackersPublisher: some Publisher<DetectedTracker, Never>,
         urlPublisher: some Publisher<URL?, Never>,
         titlePublisher: some Publisher<String?, Never>) {

        self.historyCoordinating = historyCoordinating
        self.isBurner = isBurner
        super.init()

        trackersPublisher.sink { [weak self] tracker in
            guard let self,
                  let url = URL(string: tracker.request.pageUrl) else { return }

            switch tracker.type {
            case .tracker:
                self.historyCoordinating.addDetectedTracker(tracker.request, on: url)
            case .trackerWithSurrogate:
                self.historyCoordinating.addDetectedTracker(tracker.request, on: url)
            case .thirdPartyRequest:
                break
            }
        }.store(in: &cancellables)

        urlPublisher
            .assign(to: \.url, onWeaklyHeld: self)
            .store(in: &cancellables)

        titlePublisher
            .sink { [weak self] title in
                guard let self,
                      let title else { return }
                self.updateVisitTitle(title)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminate(_:)),
                                               name: NSApplication.willTerminateNotification,
                                               object: nil)
    }

    private func addVisit() {
        guard !isBurner else { return }

        guard let url else {
            assertionFailure("HistoryTabExtension.state.currentUrl not set")
            return
        }

        // Add to global history
        historyCoordinating.addVisit(of: url)

        // Add to local history
        if let host = url.host?.droppingWwwPrefix(), !host.isEmpty {
            localHistory.insert(host)
        }

        self.visitState = .added
    }

    private func updateVisitTitle(_ title: String) {
        guard !isBurner else { return }

        guard let url else { return }
        historyCoordinating.updateTitleIfNeeded(title: title, url: url)
    }

    private func commitBeforeClosing() {
        guard !isBurner else { return }

        guard let url else { return }
        historyCoordinating.commitChanges(url: url)
    }

    @objc private func applicationWillTerminate(_: Notification) {
        commitBeforeClosing()
    }

    deinit {
        commitBeforeClosing()
    }

}

extension HistoryTabExtension: NSCodingExtension {

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

}

extension HistoryCoordinating {

    func addDetectedTracker(_ tracker: DetectedRequest, on url: URL) {
        trackerFound(on: url)

        guard tracker.isBlocked,
              let entityName = tracker.entityName else { return }

        addBlockedTracker(entityName: entityName, on: url)
    }

}

extension HistoryTabExtension: NavigationResponder {

    @MainActor
    func didCommit(_ navigation: Navigation) {
        guard navigation.url == self.url,
              navigation.url.isHypertextURL,
              case .expected = visitState else { return }

        guard !navigation.navigationAction.navigationType.isBackForward,
              !navigation.navigationAction.navigationType.isSessionRestoration,
              navigation.navigationAction.navigationType != .reload else {
            // mark navigation visit as already added to ignore possible next same-document navigations
            self.visitState = .added
            return
        }

        addVisit()
    }

    func willStart(_ navigation: Navigation) {
        if case .sameDocumentNavigation = navigation.navigationAction.navigationType {
            self.url = navigation.navigationAction.url
            addVisit()
        }
    }

    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        switch error {
        case URLError.notConnectedToInternet,
             URLError.networkConnectionLost:
            guard let failingUrl = error.failingUrl else { return }
            historyCoordinating.markFailedToLoadUrl(failingUrl)

        default: break
        }
    }

}

protocol HistoryExtensionProtocol: AnyObject, NavigationResponder {
    var localHistory: Set<String> { get }
}

extension HistoryTabExtension: HistoryExtensionProtocol, TabExtension {
    func getPublicProtocol() -> HistoryExtensionProtocol { self }
}

extension TabExtensions {
    var history: HistoryExtensionProtocol? { resolve(HistoryTabExtension.self) }
}

extension Tab {
    var localHistory: Set<String> {
        self.history?.localHistory ?? []
    }
}
