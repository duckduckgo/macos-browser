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
import os.log
import BrowserServicesKit
import Common
import Configuration
import Networking
import PixelKit

final class ConfigurationManager: DefaultConfigurationManager {

    static let shared = ConfigurationManager(fetcher: ConfigurationFetcher(store: ConfigurationStore.shared,
                                                                           eventMapping: configurationDebugEvents))

    static let configurationDebugEvents = EventMapping<ConfigurationDebugEvents> { event, error, _, _ in
        let domainEvent: NetworkProtectionPixelEvent
        switch event {
        case .invalidPayload(let configuration):
            domainEvent = .networkProtectionConfigurationInvalidPayload(configuration: configuration)
        }

        PixelKit.fire(DebugEvent(domainEvent, error: error))
    }

    private var fileDispatchSource: DispatchSourceFileSystemObject?

    override init(fetcher: ConfigurationFetcher, defaults: UserDefaults = UserDefaults()) {
        super.init(fetcher: fetcher, defaults: defaults)

        do {
            let fileHandle = try FileHandle(forReadingFrom: ConfigurationStore.shared.fileUrl(for: .privacyConfiguration))
            fileDispatchSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileHandle.fileDescriptor,
                eventMask: .write,
                queue: ConfigurationManager.queue
            )
            fileDispatchSource?.setEventHandler { [weak self] in
                self?.updateConfigDependencies()
            }
            fileDispatchSource?.resume()
        } catch {
            Logger.config.error("unable to set up configuration dispatch source: \(error.localizedDescription, privacy: .public)")
        }
    }

    deinit {
        fileDispatchSource?.cancel()
    }

    func log() {
        Logger.config.log("last update \(String(describing: self.lastUpdateTime), privacy: .public)")
        Logger.config.log("last refresh check \(String(describing: self.lastRefreshCheckTime), privacy: .public)")
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
            Logger.config.error(
                "Failed to complete configuration update to \(Configuration.privacyConfiguration.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            tryAgainSoon()
        }

        return false
    }

    func updateConfigDependencies() {
        VPNPrivacyConfigurationManager.shared.reload(
            etag: ConfigurationStore.shared.loadEtag(for: .privacyConfiguration),
            data: ConfigurationStore.shared.loadData(for: .privacyConfiguration)
        )
    }
}
