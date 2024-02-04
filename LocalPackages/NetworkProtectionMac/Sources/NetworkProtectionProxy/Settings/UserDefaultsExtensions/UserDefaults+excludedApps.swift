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
    private var vpnProxyAppRoutingRulesDataKey: String {
        "vpnProxyAppRoutingRulesData"
    }

    @objc
    dynamic var vpnProxyAppRoutingRulesData: Data? {
        get {
            object(forKey: vpnProxyAppRoutingRulesDataKey) as? Data
        }

        set {
            guard let newValue,
               newValue.count > 0 else {

                removeObject(forKey: vpnProxyAppRoutingRulesDataKey)
                return
            }

            set(newValue, forKey: vpnProxyAppRoutingRulesDataKey)
        }
    }

    var vpnProxyAppRoutingRules: VPNAppRoutingRules {
        get {
            guard let data = vpnProxyAppRoutingRulesData,
                  let routingRules = try? JSONDecoder().decode(VPNAppRoutingRules.self, from: data) else {
                return [:]
            }

            return routingRules
        }

        set {
            if newValue.isEmpty {
                vpnProxyAppRoutingRulesData = nil
                return
            }

            guard let data = try? JSONEncoder().encode(newValue) else {
                vpnProxyAppRoutingRulesData = nil
                return
            }

            vpnProxyAppRoutingRulesData = data
        }
    }

    var vpnProxyAppRoutingRulesPublisher: AnyPublisher<VPNAppRoutingRules, Never> {
        publisher(for: \.vpnProxyAppRoutingRulesData).map { [weak self] _ in
            self?.vpnProxyAppRoutingRules ?? [:]
        }.eraseToAnyPublisher()
    }

    func resetVPNProxyAppRoutingRules() {
        removeObject(forKey: vpnProxyAppRoutingRulesDataKey)
    }
}
