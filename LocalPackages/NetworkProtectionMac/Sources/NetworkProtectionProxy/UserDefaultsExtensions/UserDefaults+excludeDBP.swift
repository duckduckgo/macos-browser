//
//  UserDefaults+excludeDBP.swift
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
    private var vpnProxyExcludeDBPKey: String {
        "vpnProxyExcludeDBP"
    }

    dynamic var vpnProxyExcludeDBP: FeatureExclusion {
        get {
            guard let data = object(forKey: vpnProxyExcludeDBPKey) as? Data,
                  let excludeDBP = try? JSONDecoder().decode(FeatureExclusion.self, from: data) else {
                return .dontExclude
            }

            return excludeDBP
        }

        set {
            if case .dontExclude = newValue {
                removeObject(forKey: vpnProxyExcludeDBPKey)
                return
            }

            guard let data = try? JSONEncoder().encode(newValue) else {
                removeObject(forKey: vpnProxyExcludeDBPKey)
                return
            }

            set(data, forKey: vpnProxyExcludeDBPKey)
        }
    }

    var vpnProxyExcludeDBPPublisher: AnyPublisher<FeatureExclusion, Never> {
        publisher(for: \.vpnProxyExcludeDBP).eraseToAnyPublisher()
    }

    func resetVPNProxyExcludeDBP() {
        removeObject(forKey: vpnProxyExcludeDBPKey)
    }
}
