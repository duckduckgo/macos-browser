//
//  VPNUninstaller.swift
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
import NetworkProtection
import NetworkProtectionIPC

protocol VPNUninstalling {
    func uninstall(includingSystemExtension: Bool) async
}

final class VPNUninstaller: VPNUninstalling {
    let networkExtensionController: NetworkExtensionController
    let vpnConfiguration: VPNConfigurationManager
    let defaults: UserDefaults

    init(networkExtensionController: NetworkExtensionController, vpnConfigurationManager: VPNConfigurationManager, defaults: UserDefaults = .netP) {
        self.networkExtensionController = networkExtensionController
        self.vpnConfiguration = vpnConfigurationManager
        self.defaults = defaults
    }

    func uninstall(includingSystemExtension: Bool) async {
#if NETP_SYSTEM_EXTENSION
        if includingSystemExtension {
            do {
                try await networkExtensionController.deactivateSystemExtension()
                defaults.networkProtectionOnboardingStatus = .isOnboarding(step: .userNeedsToAllowExtension)
            } catch {

            }
        }
#endif

        await vpnConfiguration.removeVPNConfiguration()

        if defaults.networkProtectionOnboardingStatus == .completed {
            defaults.networkProtectionOnboardingStatus = .isOnboarding(step: .userNeedsToAllowVPNConfiguration)
        }

        defaults.networkProtectionShouldShowVPNUninstalledMessage = true
        exit(EXIT_SUCCESS)
    }
}
