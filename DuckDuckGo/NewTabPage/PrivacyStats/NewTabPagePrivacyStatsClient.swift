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
import UserScript

final class NewTabPagePrivacyStatsClient: NewTabPageScriptClient {

    weak var userScriptsSource: NewTabPageUserScriptsSource?
    private let model: NewTabPagePrivacyStatsModel
    private var cancellables: Set<AnyCancellable> = []

    enum MessageName: String, CaseIterable {
        case getConfig = "stats_getConfig"
        case getData = "stats_getData"
        case onConfigUpdate = "stats_onConfigUpdate"
        case onDataUpdate = "stats_onDataUpdate"
        case setConfig = "stats_setConfig"
    }

    init(model: NewTabPagePrivacyStatsModel) {
        self.model = model

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

    func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageName.getConfig.rawValue: { [weak self] in try await self?.getConfig(params: $0, original: $1) },
            MessageName.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.setConfig.rawValue: { [weak self] in try await self?.setConfig(params: $0, original: $1) }
        ])
    }

    func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = model.isViewExpanded ? .expanded : .collapsed
        return NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: expansion)
    }

    @MainActor
    private func notifyConfigUpdated(_ isViewExpanded: Bool) {
        let expansion: NewTabPageUserScript.WidgetConfig.Expansion = isViewExpanded ? .expanded : .collapsed
        let config = NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: expansion)
        pushMessage(named: MessageName.onConfigUpdate.rawValue, params: config)
    }

    @MainActor
    func setConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let config: NewTabPageUserScript.WidgetConfig = DecodableHelper.decode(from: params) else {
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
    func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return await model.calculatePrivacyStats()
    }
}

extension NewTabPagePrivacyStatsClient {

    struct PrivacyStatsData: Encodable, Equatable {
        let totalCount: Int64
        let trackerCompanies: [TrackerCompany]

        static func == (lhs: PrivacyStatsData, rhs: PrivacyStatsData) -> Bool {
            lhs.totalCount == rhs.totalCount && Set(lhs.trackerCompanies) == Set(rhs.trackerCompanies)
        }
    }

    struct TrackerCompany: Encodable, Equatable, Hashable {
        let count: Int64
        let displayName: String

        static func otherCompanies(count: Int64) -> TrackerCompany {
            TrackerCompany(count: count, displayName: "__other__")
        }
    }
}
