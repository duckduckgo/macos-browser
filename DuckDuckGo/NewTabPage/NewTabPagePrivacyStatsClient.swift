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

import UserScript

final class NewTabPagePrivacyStatsClient: NewTabPageScriptClient {

    weak var userScriptsSource: NewTabPageUserScriptsSource?

    enum MessageNames: String, CaseIterable {
        case getConfig = "stats_getConfig"
        case getData = "stats_getData"
    }

    func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageNames.getConfig.rawValue: { [weak self] in try await self?.getConfig(params: $0, original: $1) },
            MessageNames.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
        ])
    }

    func getConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        // implementation TBD
        NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: .collapsed)
    }

    func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        // implementation TBD
        NewTabPageUserScript.PrivacyStatsData(totalCount: 0, trackerCompanies: [])
    }
}

extension NewTabPageUserScript {

    struct PrivacyStatsData: Encodable {
        let totalCount: Int
        let trackerCompanies: [TrackerCompany]
    }

    struct TrackerCompany: Encodable {
        let count: Int
        let displayName: String
    }
}
