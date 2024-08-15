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
import PixelKit

final class ConfigurationManager: DefaultConfigurationManager {

    static let shared = ConfigurationManager(fetcher: ConfigurationFetcher(store: ConfigurationStore.shared,
                                                                           log: .default,
                                                                           eventMapping: nil))
    // TODO: EventMapping for error pixels

    override public func refreshNow(isDebug: Bool = false) async {
        let updateConfigDependenciesTask = Task {
            let didFetchConfig = await fetchConfigDependencies(isDebug: isDebug)
            if didFetchConfig {
                updateConfigDependencies()
                tryAgainLater()
            }
        }

        await updateConfigDependenciesTask.value

//        ConfigurationStore.shared.log()
//        log()
    }

    func fetchConfigDependencies(isDebug: Bool) async -> Bool {
        do {
            try await fetcher.fetch(.privacyConfiguration, isDebug: isDebug)
            return true
        } catch {
            os_log("Failed to complete configuration update to %@: %@",
                   log: .default,
                   type: .error,
                   Configuration.privacyConfiguration.rawValue,
                   error.localizedDescription)
            tryAgainSoon()
        }

        return false
    }

    func updateConfigDependencies() {
        // TODO: Update lastConfigurationInstallDate
        // TODO: Provide config to dependency manager
    }
}
