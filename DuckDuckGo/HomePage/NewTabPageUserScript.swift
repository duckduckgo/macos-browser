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

final class NewTabPageUserScript: NSObject, @preconcurrency Subfeature {

    let actionsManager: NewTabPageActionsManaging
    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [.exact(hostname: "newtab")])
    let featureName: String = "newTabPage"
    weak var broker: UserScriptMessageBroker?
    var webViews: NSHashTable<WKWebView> = .weakObjects()

    // MARK: - MessageNames
    enum MessageNames: String, CaseIterable {
        case contextMenu
        case initialSetup
        case reportInitException
        case reportPageException
        case widgetsSetConfig = "widgets_setConfig"
    }

    init(actionsManager: NewTabPageActionsManaging) {
        self.actionsManager = actionsManager
        super.init()
        actionsManager.userScript = self
    }

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    private lazy var methodHandlers: [MessageNames: Handler] = [
        .contextMenu: { [weak self] in try await self?.showContextMenu(params: $0, original: $1) },
        .initialSetup: { [weak self] in try await self?.initialSetup(params: $0, original: $1) },
        .reportInitException: { [weak self] in try await self?.reportException(params: $0, original: $1) },
        .reportPageException: { [weak self] in try await self?.reportException(params: $0, original: $1) },
        .widgetsSetConfig: { [weak self] in try await self?.widgetsSetConfig(params: $0, original: $1) }
    ]

    @MainActor
    func handler(forMethodNamed methodName: String) -> Handler? {
        guard let messageName = MessageNames(rawValue: methodName) else { return nil }
        return methodHandlers[messageName]
    }

    func widgetConfigsUpdated(widgetConfigs: [NewTabPageConfiguration.WidgetConfig]) {
        for webView in webViews.allObjects {
            broker?.push(method: "widgets_onConfigUpdated", params: widgetConfigs, for: self, into: webView)
        }
    }
}

extension NewTabPageUserScript {
    @MainActor
    private func initialSetup(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return actionsManager.configuration
    }

    @MainActor
    private func widgetsSetConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [[String: String]] else { return nil }
        actionsManager.updateWidgetConfigs(with: params)
        return nil
    }

    @MainActor
    private func showContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: Any] else { return nil }
        actionsManager.showContextMenu(with: params)
        return nil
    }

    private func reportException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: String] else { return nil }
        actionsManager.reportException(with: params)
        return nil
    }

    struct Result: Encodable {}

}
