//
//  DataBrokerProtectionAgentKiller.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Common

protocol DataBrokerProtectionAgentKiller {
    func validatePreRequisitesAndKillAgentIfNecessary() async
    func monitorEntitlementAndKillAgentIfNecessary()
    func killAgent()
}

struct DefaultDataBrokerProtectionAgentKiller: DataBrokerProtectionAgentKiller {
    private let dataManager: DataBrokerProtectionDataManaging
    private let entitlementMonitor: DataBrokerProtectionEntitlementMonitoring
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging

    init(dataManager: DataBrokerProtectionDataManaging,
         entitlementMonitor: DataBrokerProtectionEntitlementMonitoring,
         authenticationManager: DataBrokerProtectionAuthenticationManaging) {
        self.dataManager = dataManager
        self.entitlementMonitor = entitlementMonitor
        self.authenticationManager = authenticationManager
    }

    public func validatePreRequisitesAndKillAgentIfNecessary() async {
        do {
            guard try dataManager.fetchProfile() != nil,
                  authenticationManager.isUserAuthenticated,
                  try await authenticationManager.hasValidEntitlement() else {

                os_log("Prerequisites are invalid", log: .dataBrokerProtection)
                killAgent()
                return
            }
            os_log("Prerequisites are valid", log: .dataBrokerProtection)
        } catch {
            os_log("Error validating prerequisites, error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
            killAgent()
        }
    }

    public func monitorEntitlementAndKillAgentIfNecessary() {
        entitlementMonitor.start(checkEntitlementFunction: authenticationManager.hasValidEntitlement) { result in
            switch result {
            case .enabled:
#warning("Send pixel enabled")
                killAgent()
            case .disabled:
#warning("Send pixel disabled")
            case .error:
#warning("Send pixel error")
            }
        }
    }

    func killAgent() {
        os_log("Killing DataBrokerProtection Agent", log: .dataBrokerProtection)
        exit(EXIT_SUCCESS)
    }
}
