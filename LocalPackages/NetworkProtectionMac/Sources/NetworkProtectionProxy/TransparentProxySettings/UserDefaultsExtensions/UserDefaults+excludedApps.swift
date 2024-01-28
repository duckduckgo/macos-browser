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
    private var vpnProxyExcludedAppsKey: String {
        "vpnProxyExcludedApps"
    }

    dynamic var vpnProxyExcludedApps: [AppIdentifier] {
        get {
            guard let data = object(forKey: vpnProxyExcludedAppsKey) as? Data,
                  let excludedApps = try? JSONDecoder().decode([AppIdentifier].self, from: data) else {
                return []
            }

            return excludedApps
        }

        set {
            if newValue.isEmpty {
                removeObject(forKey: vpnProxyExcludedAppsKey)
                return
            }

            guard let data = try? JSONEncoder().encode(newValue) else {
                removeObject(forKey: vpnProxyExcludedAppsKey)
                return
            }

            set(data, forKey: vpnProxyExcludedAppsKey)
        }
    }

    var vpnProxyExcludedAppsPublisher: AnyPublisher<[AppIdentifier], Never> {
        publisher(for: \.vpnProxyExcludedApps).eraseToAnyPublisher()
    }

    func resetVPNProxyExcludedApps() {
        removeObject(forKey: vpnProxyExcludedAppsKey)
    }
}
