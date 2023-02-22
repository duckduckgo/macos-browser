//
//  HTTPSUpgradeTabExtension.swift
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
import Navigation

final class HTTPSUpgradeTabExtension {

    private let httpsUpgrade: HTTPSUpgrade

    private var lastUpgradedURL: URL?

    private var didUpgradeToHttpsSubject = PassthroughSubject<URL, Never>()

    init(httpsUpgrade: HTTPSUpgrade) {
        self.httpsUpgrade = httpsUpgrade
    }

}

extension HTTPSUpgradeTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        guard navigationAction.isForMainFrame else { return .next }

        // resetting lastUpgradedURL for new navigation or cross-domain navigation
        if (navigationAction.navigationType == .other && !navigationAction.isUserInitiated)
            || navigationAction.request.mainDocumentURL?.host != lastUpgradedURL?.host {
            lastUpgradedURL = nil
        }

        guard case let .success(upgradedURL) = await httpsUpgrade.upgrade(url: navigationAction.url),
              lastUpgradedURL != upgradedURL
        else { return .next }

        lastUpgradedURL = upgradedURL
        didUpgradeToHttpsSubject.send(upgradedURL)

        return .redirectInvalidatingBackItemIfNeeded(navigationAction) {
            $0.load(URLRequest(url: upgradedURL))
        }
    }

}

protocol HTTPSUpgradeExtensionProtocol: AnyObject, NavigationResponder {
    var didUpgradeToHttpsPublisher: AnyPublisher<URL, Never> { get }
}

extension HTTPSUpgradeTabExtension: TabExtension, HTTPSUpgradeExtensionProtocol {
    typealias PublicProtocol = HTTPSUpgradeExtensionProtocol
    func getPublicProtocol() -> PublicProtocol { self }

    var didUpgradeToHttpsPublisher: AnyPublisher<URL, Never> {
        didUpgradeToHttpsSubject.eraseToAnyPublisher()
    }
}

extension TabExtensions {
    var httpsUpgrade: HTTPSUpgradeExtensionProtocol? {
        resolve(HTTPSUpgradeTabExtension.self)
    }
}
