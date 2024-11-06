//
//  NetworkProtectionControllerTabExtension.swift
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
import Navigation
import NetworkProtection
import PixelKit

final class NetworkProtectionControllerTabExtension {
    let tunnelController: NetworkProtectionIPCTunnelController

    init(tunnelController: NetworkProtectionIPCTunnelController) {
        self.tunnelController = tunnelController
    }
}

extension NetworkProtectionControllerTabExtension: NavigationResponder {
    func navigationDidFinish(_ navigation: Navigation) {
        if navigation.url.isDuckDuckGoSearch, tunnelController.isConnected == true {
            PixelKit.fire(GeneralPixel.networkProtectionEnabledOnSearch, frequency: .legacyDailyAndCount)
        }
    }
}

protocol NetworkProtectionTabExtensionProtocol: AnyObject, NavigationResponder {
    var tunnelController: NetworkProtectionIPCTunnelController { get }
}

extension NetworkProtectionControllerTabExtension: TabExtension, NetworkProtectionTabExtensionProtocol {
    typealias PublicProtocol = NetworkProtectionTabExtensionProtocol
    func getPublicProtocol() -> PublicProtocol { self }
}

extension TabExtensions {
    var networkProtection: NetworkProtectionTabExtensionProtocol? {
        resolve(NetworkProtectionControllerTabExtension.self)
    }
}
