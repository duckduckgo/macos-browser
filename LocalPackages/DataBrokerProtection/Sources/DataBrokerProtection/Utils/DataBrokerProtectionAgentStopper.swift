//
//  DataBrokerProtectionAgentStopper.swift
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
import Freemium

protocol DataBrokerProtectionAgentStopper {
    /// Validates if the user has is an active freemium user, OR if they have profile data, is authenticated, and has valid entitlement. If any of these conditions are not met, the agent will be stopped.
    func validateRunPrerequisitesAndStopAgentIfNecessary() async

    /// Monitors the entitlement package. If the entitlement check returns false, and the user is NOT an active freemium user, the agent will be stopped.
    /// This function ensures that the agent is stopped if the user's subscription has expired, even if the browser is not active. Regularly checking for entitlement is required since notifications are not posted to agents.
    func monitorEntitlementAndStopAgentIfEntitlementIsInvalidAndUserIsNotFreemium(interval: TimeInterval)
}

struct DefaultDataBrokerProtectionAgentStopper: DataBrokerProtectionAgentStopper {
    private let dataManager: DataBrokerProtectionDataManaging
    private let entitlementMonitor: DataBrokerProtectionEntitlementMonitoring
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let stopAction: DataProtectionStopAction
    private let freemiumPIRUserState: FreemiumPIRUserState

    init(dataManager: DataBrokerProtectionDataManaging,
         entitlementMonitor: DataBrokerProtectionEntitlementMonitoring,
         authenticationManager: DataBrokerProtectionAuthenticationManaging,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         stopAction: DataProtectionStopAction = DefaultDataProtectionStopAction(),
         freemiumPIRUserState: FreemiumPIRUserState) {
        self.dataManager = dataManager
        self.entitlementMonitor = entitlementMonitor
        self.authenticationManager = authenticationManager
        self.pixelHandler = pixelHandler
        self.stopAction = stopAction
        self.freemiumPIRUserState = freemiumPIRUserState
    }

    /// Checks PIR prerequisites and stops the agent if necessary
    ///
    /// Prerequisites are satisified if either:
    /// 1. The user is an active freemium user
    /// 2. The user has a subscription with valid entitlements
    public func validateRunPrerequisitesAndStopAgentIfNecessary() async {

        let isFreemiumUser = freemiumPIRUserState.isActiveUser

        do {
            guard try dataManager.fetchProfile() != nil, isFreemiumUser ||
                  authenticationManager.isUserAuthenticated else {
                os_log("Prerequisites are invalid", log: .dataBrokerProtection)
                stopAgent()
                return
            }
            os_log("Prerequisites are valid", log: .dataBrokerProtection)
        } catch {
            os_log("Error validating prerequisites, error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
            stopAgent()
        }

        do {
            let result = try await authenticationManager.hasValidEntitlement()
            stopAgentBasedOnEntitlementCheckResult(result ? .enabled : .disabled)
        } catch {
            stopAgentBasedOnEntitlementCheckResult(.error)
        }
    }

    public func monitorEntitlementAndStopAgentIfEntitlementIsInvalidAndUserIsNotFreemium(interval: TimeInterval) {
        entitlementMonitor.start(checkEntitlementFunction: authenticationManager.hasValidEntitlement,
                                 interval: interval) { result in
            guard !self.freemiumPIRUserState.isActiveUser else { return }
            stopAgentBasedOnEntitlementCheckResult(result)
        }
    }

    private func stopAgent() {
        stopAction.stopAgent()
    }

    private func stopAgentBasedOnEntitlementCheckResult(_ result: DataBrokerProtectionEntitlementMonitorResult) {
        switch result {
        case .enabled:
            os_log("Valid entitlement", log: .dataBrokerProtection)
            pixelHandler.fire(.entitlementCheckValid)
        case .disabled:
            os_log("Invalid entitlement", log: .dataBrokerProtection)
            pixelHandler.fire(.entitlementCheckInvalid)
            stopAgent()
        case .error:
            os_log("Error when checking entitlement", log: .dataBrokerProtection)
            /// We don't want to disable the agent in case of an error while checking for entitlements.
            /// Since this is a destructive action, the only situation that should cause the data to be deleted and the agent to be removed is .success(false)
            pixelHandler.fire(.entitlementCheckError)
        }
    }
}

protocol DataProtectionStopAction {
    func stopAgent()
}

struct DefaultDataProtectionStopAction: DataProtectionStopAction {
    func stopAgent() {
        os_log("Stopping DataBrokerProtection Agent", log: .dataBrokerProtection)
        exit(EXIT_SUCCESS)
    }
}
