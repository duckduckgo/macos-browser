//
//  PrivacyPreferencesModel.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import NetworkProtection

final class VPNPreferencesModel: ObservableObject {
    @Published var isAutoconsentEnabled: Bool = true

    @Published var connectOnLogin: Bool {
        didSet {
            tunnelSettings.connectOnLogin = connectOnLogin
        }
    }

    @Published var excludeLocalNetworks: Bool {
        didSet {
            tunnelSettings.excludeLocalNetworks = excludeLocalNetworks
        }
    }

    @Published var showInMenuBar: Bool {
        didSet {
            tunnelSettings.showInMenuBar = showInMenuBar
        }
    }

    private let tunnelSettings: TunnelSettings

    init(tunnelSettings: TunnelSettings = .init(defaults: .shared)) {
        self.tunnelSettings = tunnelSettings

        connectOnLogin = tunnelSettings.connectOnLogin
        excludeLocalNetworks = tunnelSettings.excludeLocalNetworks
        showInMenuBar = tunnelSettings.showInMenuBar
    }
}
