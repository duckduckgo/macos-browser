//
//  NewTabPagePrivacyStatsClient.swift
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
import Common
import os.log
import UserScriptActionsManager
import WebKit

public final class NewTabPagePrivacyStatsClient: NewTabPageUserScriptClient {

    private let model: NewTabPagePrivacyStatsModel
    private var cancellables: Set<AnyCancellable> = []

    enum MessageName: String, CaseIterable {
        case getConfig = "stats_getConfig"
        case getData = "stats_getData"
        case onConfigUpdate = "stats_onConfigUpdate"
        case onDataUpdate = "stats_onDataUpdate"
        case setConfig = "stats_setConfig"
        case showLess = "stats_showLess"
        case showMore = "stats_showMore"
    }

    public init(model: NewTabPagePrivacyStatsModel) {
        self.model = model
        super.init()

        model.$isViewExpanded.dropFirst()
            .sink { [weak self] isExpanded in
                Task { @MainActor in
                    self?.notifyConfigUpdated(isExpanded)
                }
            }
            .store(in: &cancellables)

        model.statsUpdatePublisher
            .sink { [weak self] in
                Task { @MainActor in
                    await self?.notifyDataUpdated()
                }
            }
            .store(in: &cancellables)
    }

    public override func registerMessageHandlers(for userScript: NewTabPageUserScript) {
        userScript.registerMessageHandlers([
            MessageName.getConfig.rawValue: { [weak self] in try await self?.getConfig(params: $0, original: $1) },
            MessageName.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.setConfig.rawValue: { [weak self] in try await self?.setConfig(params: $0, original: $1) },
            MessageName.showLess.rawValue: { [weak self] in try await self?.showLess(params: $0, original: $1) },
            MessageName.showMore.rawValue: { [weak self] in try await self?.showMore(params: $0, original: $1) }
        ])
    }

    private func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = model.isViewExpanded ? .expanded : .collapsed
        return NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: expansion)
    }

    @MainActor
    private func notifyConfigUpdated(_ isViewExpanded: Bool) {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = isViewExpanded ? .expanded : .collapsed
        let config = NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: expansion)
        pushMessage(named: MessageName.onConfigUpdate.rawValue, params: config)
    }

    @MainActor
    private func setConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let config: NewTabPageUserScript.WidgetConfig = CodableHelper.decode(from: params) else {
            return nil
        }
        model.isViewExpanded = config.expansion == .expanded
        return nil
    }

    @MainActor
    private func notifyDataUpdated() async {
        pushMessage(named: MessageName.onDataUpdate.rawValue, params: await model.calculatePrivacyStats())
    }

    @MainActor
    private func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return await model.calculatePrivacyStats()
    }

    @MainActor
    private func showLess(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        model.showLess()
        return nil
    }

    @MainActor
    private func showMore(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        model.showMore()
        return nil
    }
}
