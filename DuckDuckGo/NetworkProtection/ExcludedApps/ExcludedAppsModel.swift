//
//  ExcludedAppsModel.swift
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
import NetworkProtectionProxy
import NetworkProtectionUI
import PixelKit

protocol ExcludedAppsModel {
    var excludedApps: [String] { get }

    func add(bundleID: String)
    func remove(bundleID: String)
}

final class DefaultExcludedAppsModel {
    let proxySettings = TransparentProxySettings(defaults: .netP)
    private let pixelKit: PixelFiring?

    init(pixelKit: PixelFiring? = PixelKit.shared) {
        self.pixelKit = pixelKit
    }
}

extension DefaultExcludedAppsModel: ExcludedAppsModel {
    var excludedApps: [String] {
        proxySettings.excludedApps
    }

    func add(bundleID: String) {
        guard proxySettings.appRoutingRules[bundleID] != .exclude else {
            return
        }

        proxySettings.appRoutingRules[bundleID] = .exclude
    }

    func remove(bundleID: String) {
        guard proxySettings.appRoutingRules[bundleID] == .exclude else {
            return
        }

        proxySettings.appRoutingRules.removeValue(forKey: bundleID)
    }
}
