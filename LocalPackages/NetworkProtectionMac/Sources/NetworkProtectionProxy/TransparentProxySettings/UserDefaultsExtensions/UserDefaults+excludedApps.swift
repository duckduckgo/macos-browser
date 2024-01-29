//
//  UserDefaults+excludedApps.swift
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
import Foundation

extension UserDefaults {
    private var vpnProxyExcludedAppsDataKey: String {
        "vpnProxyExcludedAppsData"
    }

    @objc
    dynamic var vpnProxyExcludedAppsData: Data? {
        get {
            object(forKey: vpnProxyExcludedAppsDataKey) as? Data
        }

        set {
            guard let newValue,
               newValue.count > 0 else {

                removeObject(forKey: vpnProxyExcludedAppsDataKey)
                return
            }

            set(newValue, forKey: vpnProxyExcludedAppsDataKey)
        }
    }

    var vpnProxyExcludedApps: [AppIdentifier] {
        get {
            guard let data = vpnProxyExcludedAppsData,
                  let excludedApps = try? JSONDecoder().decode([AppIdentifier].self, from: data) else {
                return []
            }

            return excludedApps
        }

        set {
            if newValue.isEmpty {
                vpnProxyExcludedAppsData = nil
                return
            }

            guard let data = try? JSONEncoder().encode(newValue) else {
                vpnProxyExcludedAppsData = nil
                return
            }

            vpnProxyExcludedAppsData = data
        }
    }

    var vpnProxyExcludedAppsPublisher: AnyPublisher<[AppIdentifier], Never> {
        publisher(for: \.vpnProxyExcludedAppsData).map { [weak self] _ in
            self?.vpnProxyExcludedApps ?? []
        }.eraseToAnyPublisher()
        //Just([]).eraseToAnyPublisher()
    }

    func resetVPNProxyExcludedApps() {
        removeObject(forKey: vpnProxyExcludedAppsDataKey)
    }
}
