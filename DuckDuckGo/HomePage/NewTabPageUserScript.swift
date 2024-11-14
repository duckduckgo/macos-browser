//
//  NewTabPageUserScript.swift
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
import UserScript
import WebKit

final class NewTabPageUserScript: NSObject, Subfeature {

    let actionsManager: NewTabPageActionsManaging
    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [.exact(hostname: "newtab")])
    let featureName: String = "newTabPage"
    weak var broker: UserScriptMessageBroker?
    weak var webView: WKWebView?

    // MARK: - MessageNames
    enum MessageNames: String, CaseIterable {
        case contextMenu
        case favoritesGetConfig = "favorites_getConfig"
        case favoritesGetData = "favorites_getData"
        case initialSetup
        case reportInitException
        case reportPageException
        case statsGetConfig = "stats_getConfig"
        case statsGetData = "stats_getData"
        case widgetsSetConfig = "widgets_setConfig"
    }

    init(actionsManager: NewTabPageActionsManaging) {
        self.actionsManager = actionsManager
        super.init()
        actionsManager.registerUserScript(self)
    }

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    private lazy var methodHandlers: [MessageNames: Handler] = [
        .contextMenu: { [weak self] in try await self?.showContextMenu(params: $0, original: $1) },
        .favoritesGetConfig: { [weak self] in try await self?.favoritesGetConfig(params: $0, original: $1) },
        .favoritesGetData: { [weak self] in try await self?.favoritesGetData(params: $0, original: $1) },
        .initialSetup: { [weak self] in try await self?.initialSetup(params: $0, original: $1) },
        .reportInitException: { [weak self] in try await self?.reportException(params: $0, original: $1) },
        .reportPageException: { [weak self] in try await self?.reportException(params: $0, original: $1) },
        .statsGetConfig: { [weak self] in try await self?.statsGetConfig(params: $0, original: $1) },
        .statsGetData: { [weak self] in try await self?.statsGetData(params: $0, original: $1) },
        .widgetsSetConfig: { [weak self] in try await self?.widgetsSetConfig(params: $0, original: $1) }
    ]

    @MainActor
    func handler(forMethodNamed methodName: String) -> Handler? {
        guard let messageName = MessageNames(rawValue: methodName) else { return nil }
        return methodHandlers[messageName]
    }

    func notifyWidgetConfigsDidChange(widgetConfigs: [NewTabPageConfiguration.WidgetConfig]) {
        guard let webView else {
            return
        }
        broker?.push(method: "widgets_onConfigUpdated", params: widgetConfigs, for: self, into: webView)
    }
}

extension NewTabPageUserScript {
    @MainActor
    private func showContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: Any] else { return nil }
        actionsManager.showContextMenu(with: params)
        return nil
    }

    @MainActor
    private func favoritesGetConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        actionsManager.getFavoritesConfig()
    }

    @MainActor
    private func favoritesGetData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        actionsManager.getFavorites()
    }

    @MainActor
    private func initialSetup(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        actionsManager.configuration
    }

    @MainActor
    private func statsGetConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        actionsManager.getPrivacyStatsConfig()
    }

    @MainActor
    private func statsGetData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        actionsManager.getPrivacyStats()
    }

    @MainActor
    private func widgetsSetConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [[String: String]] else { return nil }
        actionsManager.updateWidgetConfigs(with: params)
        return nil
    }

    private func reportException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: String] else { return nil }
        actionsManager.reportException(with: params)
        return nil
    }
}

extension NewTabPageUserScript {

    struct NewTabPageConfiguration: Encodable {
        var widgets: [Widget]
        var widgetConfigs: [WidgetConfig]
        var env: String
        var locale: String
        var platform: Platform

        struct Widget: Encodable {
            var id: String
        }

        struct WidgetConfig: Encodable {

            enum WidgetVisibility: String, Encodable {
                case visible, hidden

                var isVisible: Bool {
                    self == .visible
                }
            }

            init(id: String, isVisible: Bool) {
                self.id = id
                self.visibility = isVisible ? .visible : .hidden
            }

            var id: String
            var visibility: WidgetVisibility
        }

        struct Platform: Encodable {
            var name: String
        }
    }

    struct WidgetConfig: Encodable {
        let animation: Animation?
        let expansion: Expansion
    }

    enum Expansion: String, Encodable {
        case collapsed, expanded
    }

    struct Animation: Encodable {
        let kind: AnimationKind

        static let none = Animation(kind: .none)
        static let viewTransitions = Animation(kind: .viewTransitions)
        static let auto = Animation(kind: .auto)

        enum AnimationKind: String, Encodable {
            case none
            case viewTransitions = "view-transitions"
            case auto = "auto-animate"
        }
    }

    struct FavoritesData: Encodable {
        let favorites: [Favorite]
    }

    struct Favorite: Encodable {
        let favicon: FavoriteFavicon?
        let id: String
        let title: String
        let url: String
    }

    struct FavoriteFavicon: Encodable {
        let maxAvailableSize: Int
        let src: String
    }

    struct PrivacyStatsData: Encodable {
        let totalCount: Int
        let trackerCompanies: [TrackerCompany]
    }

    struct TrackerCompany: Encodable {
        let count: Int
        let displayName: String
    }
}
