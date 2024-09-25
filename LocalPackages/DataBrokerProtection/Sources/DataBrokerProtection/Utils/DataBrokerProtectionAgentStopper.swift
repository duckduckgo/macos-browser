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
import os.log
import Common

protocol DataBrokerProtectionAgentStopper {
    /// Validates if the user has profile data, is authenticated, and has valid entitlement. If any of these conditions are not met, the agent will be stopped.
    func validateRunPrerequisitesAndStopAgentIfNecessary() async

    /// Monitors the entitlement package. If the entitlement check returns false, the agent will be stopped.
    /// This function ensures that the agent is stopped if the user's subscription has expired, even if the browser is not active. Regularly checking for entitlement is required since notifications are not posted to agents.
    func monitorEntitlementAndStopAgentIfEntitlementIsInvalid(interval: TimeInterval)
}

struct DefaultDataBrokerProtectionAgentStopper: DataBrokerProtectionAgentStopper {
    private let dataManager: DataBrokerProtectionDataManaging
    private let entitlementMonitor: DataBrokerProtectionEntitlementMonitoring
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let stopAction: DataProtectionStopAction

    init(dataManager: DataBrokerProtectionDataManaging,
         entitlementMonitor: DataBrokerProtectionEntitlementMonitoring,
         authenticationManager: DataBrokerProtectionAuthenticationManaging,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         stopAction: DataProtectionStopAction = DefaultDataProtectionStopAction()) {
        self.dataManager = dataManager
        self.entitlementMonitor = entitlementMonitor
        self.authenticationManager = authenticationManager
        self.pixelHandler = pixelHandler
        self.stopAction = stopAction
    }

    public func validateRunPrerequisitesAndStopAgentIfNecessary() async {
        do {
            guard try dataManager.fetchProfile() != nil,
                  authenticationManager.isUserAuthenticated else {
                Logger.dataBrokerProtection.debug("Prerequisites are invalid")
                stopAgent()
                return
            }
            Logger.dataBrokerProtection.debug("Prerequisites are valid")
        } catch {
            Logger.dataBrokerProtection.error("Error validating prerequisites, error: \(error.localizedDescription, privacy: .public)")
            stopAgent()
        }

        do {
            let result = try await authenticationManager.hasValidEntitlement()
            stopAgentBasedOnEntitlementCheckResult(result ? .enabled : .disabled)
        } catch {
            stopAgentBasedOnEntitlementCheckResult(.error)
        }
    }

    public func monitorEntitlementAndStopAgentIfEntitlementIsInvalid(interval: TimeInterval) {
        entitlementMonitor.start(checkEntitlementFunction: authenticationManager.hasValidEntitlement,
                                 interval: interval) { result in
            stopAgentBasedOnEntitlementCheckResult(result)
        }
    }

    private func stopAgent() {
        stopAction.stopAgent()
    }

    private func stopAgentBasedOnEntitlementCheckResult(_ result: DataBrokerProtectionEntitlementMonitorResult) {
        switch result {
        case .enabled:
            Logger.dataBrokerProtection.debug("Valid entitlement")
            pixelHandler.fire(.entitlementCheckValid)
        case .disabled:
            Logger.dataBrokerProtection.debug("Invalid entitlement")
            pixelHandler.fire(.entitlementCheckInvalid)
            stopAgent()
        case .error:
            Logger.dataBrokerProtection.debug("Error when checking entitlement")
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
        Logger.dataBrokerProtection.debug("Stopping DataBrokerProtection Agent")
        exit(EXIT_SUCCESS)
    }
}
