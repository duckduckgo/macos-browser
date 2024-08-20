//
//  ConfigurationManager.swift
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
import BrowserServicesKit
import Configuration
import Common
import Networking
import PixelKit

final class ConfigurationManager: DefaultConfigurationManager {

    static let shared = ConfigurationManager(fetcher: ConfigurationFetcher(store: ConfigurationStore.shared,
                                                                           log: .config,
                                                                           eventMapping: configurationDebugEvents))

    static let configurationDebugEvents = EventMapping<ConfigurationDebugEvents> { event, error, _, _ in
        let domainEvent: DataBrokerProtectionPixels
        switch event {
        case .invalidPayload(let configuration):
            domainEvent = .invalidPayload(configuration)
        }

        PixelKit.fire(DebugEvent(domainEvent, error: error))
    }

    func log() {
        os_log("last update %{public}s", log: .config, type: .default, String(describing: lastUpdateTime))
        os_log("last refresh check %{public}s", log: .config, type: .default, String(describing: lastRefreshCheckTime))
    }

    override public func refreshNow(isDebug: Bool = false) async {
        let updateConfigDependenciesTask = Task {
            let didFetchConfig = await fetchConfigDependencies(isDebug: isDebug)
            if didFetchConfig {
                updateConfigDependencies()
                tryAgainLater()
            }
        }

        await updateConfigDependenciesTask.value

        ConfigurationStore.shared.log()
        log()
    }

    func fetchConfigDependencies(isDebug: Bool) async -> Bool {
        do {
            try await fetcher.fetch(.privacyConfiguration, isDebug: isDebug)
            return true
        } catch {
            os_log("Failed to complete configuration update to %@: %@",
                   log: .config,
                   type: .error,
                   Configuration.privacyConfiguration.rawValue,
                   error.localizedDescription)
            tryAgainSoon()
        }

        return false
    }

    func updateConfigDependencies() {
        DBPPrivacyConfigurationManager.shared.reload(
            etag: ConfigurationStore.shared.loadEtag(for: .privacyConfiguration),
            data: ConfigurationStore.shared.loadData(for: .privacyConfiguration)
        )
    }
}
