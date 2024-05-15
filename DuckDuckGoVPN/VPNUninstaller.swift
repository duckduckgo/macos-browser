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
import PixelKit
import SystemExtensions

protocol VPNUninstalling {
    func uninstall(includingSystemExtension: Bool) async throws
    func removeSystemExtension() async throws
    func removeVPNConfiguration() async throws
}

final class VPNUninstaller: VPNUninstalling {

    let networkExtensionController: NetworkExtensionController
    let vpnConfiguration: VPNConfigurationManager
    let defaults: UserDefaults
    let pixelKit: PixelFiring?

    init(networkExtensionController: NetworkExtensionController,
         vpnConfigurationManager: VPNConfigurationManager, defaults: UserDefaults = .netP,
         pixelKit: PixelFiring?) {

        self.networkExtensionController = networkExtensionController
        self.vpnConfiguration = vpnConfigurationManager
        self.defaults = defaults
        self.pixelKit = pixelKit
    }

    func uninstall(includingSystemExtension: Bool) async throws {
        pixelKit?.fire(VPNUninstallAttempt.begin)

        do {
            try await removeSystemExtension()
            try await removeVPNConfiguration()

            if defaults.networkProtectionOnboardingStatus == .completed {
                defaults.networkProtectionOnboardingStatus = .isOnboarding(step: .userNeedsToAllowVPNConfiguration)
            }

            defaults.networkProtectionShouldShowVPNUninstalledMessage = true
            pixelKit?.fire(VPNUninstallAttempt.success)
            exit(EXIT_SUCCESS)
        } catch OSSystemExtensionError.requestCanceled {
            pixelKit?.fire(VPNUninstallAttempt.cancelled)
        } catch {
            pixelKit?.fire(VPNUninstallAttempt.failure(error))
        }
    }

    func removeSystemExtension() async throws {
#if NETP_SYSTEM_EXTENSION
        try await networkExtensionController.deactivateSystemExtension()
        defaults.networkProtectionOnboardingStatus = .isOnboarding(step: .userNeedsToAllowExtension)
#endif
    }

    func removeVPNConfiguration() async throws {
        try await VPNConfigurationManager().removeVPNConfiguration()

        if defaults.networkProtectionOnboardingStatus == .completed {
            defaults.networkProtectionOnboardingStatus = .isOnboarding(step: .userNeedsToAllowVPNConfiguration)
        }
    }
}

// MARK: - VPNUninstallAttempt

extension VPNUninstaller {
    enum VPNUninstallAttempt: PixelKitEventV2 {
        case begin
        case cancelled
        case success
        case failure(_ error: Error)

        var name: String {
            switch self {
            case .begin:
                return "vpn_controller_uninstall_attempt"

            case .cancelled:
                return "vpn_controller_uninstall_cancelled"

            case .success:
                return "vpn_controller_uninstall_success"

            case .failure:
                return "vpn_controller_uninstall_failure"
            }
        }

        var parameters: [String: String]? {
            return nil
        }

        var error: Error? {
            switch self {
            case .begin,
                    .cancelled,
                    .success:
                return nil
            case .failure(let error):
                return error
            }
        }
    }
}
