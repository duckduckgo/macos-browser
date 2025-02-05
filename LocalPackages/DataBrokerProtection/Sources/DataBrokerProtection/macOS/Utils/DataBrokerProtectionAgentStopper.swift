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
import Freemium

protocol DataBrokerProtectionAgentStopper {
    /// Validates if the user is an active freemium user, OR if they have profile data, is authenticated, and has valid entitlement. If any of these conditions are not met, the agent will be stopped.
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
    private let freemiumDBPUserStateManager: FreemiumDBPUserStateManager

    init(dataManager: DataBrokerProtectionDataManaging,
         entitlementMonitor: DataBrokerProtectionEntitlementMonitoring,
         authenticationManager: DataBrokerProtectionAuthenticationManaging,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         stopAction: DataProtectionStopAction = DefaultDataProtectionStopAction(),
         freemiumDBPUserStateManager: FreemiumDBPUserStateManager) {
        self.dataManager = dataManager
        self.entitlementMonitor = entitlementMonitor
        self.authenticationManager = authenticationManager
        self.pixelHandler = pixelHandler
        self.stopAction = stopAction
        self.freemiumDBPUserStateManager = freemiumDBPUserStateManager
    }

    /// Checks PIR prerequisites and stops the agent if necessary
    ///
    /// Prerequisites are satisified if either:
    /// 1. The user is an active freemium user
    /// 2. The user has a subscription with valid entitlements
    public func validateRunPrerequisitesAndStopAgentIfNecessary() async {

        do {
            let hasProfile = try dataManager.fetchProfile() != nil
            let isAuthenticated = authenticationManager.isUserAuthenticated
            let didActivateFreemium = freemiumDBPUserStateManager.didActivate

            if !hasProfile || (!isAuthenticated && !didActivateFreemium) {
                Logger.dataBrokerProtection.log("Prerequisites are invalid")
                stopAgent()
                return
            }

            if satisfiesFreemiumPrerequisites() {
                Logger.dataBrokerProtection.log("User is Freemium")
                return
            }

            let hasValidEntitlement = try await authenticationManager.hasValidEntitlement()
            stopAgentBasedOnEntitlementCheckResult(hasValidEntitlement ? .enabled : .disabled)

        } catch {
            Logger.dataBrokerProtection.error("Error validating prerequisites, error: \(error.localizedDescription, privacy: .public)")
            stopAgentBasedOnEntitlementCheckResult(.error)
        }
    }

    public func monitorEntitlementAndStopAgentIfEntitlementIsInvalidAndUserIsNotFreemium(interval: TimeInterval) {
        entitlementMonitor.start(checkEntitlementFunction: authenticationManager.hasValidEntitlement,
                                 interval: interval) { result in

            if satisfiesFreemiumPrerequisites() { return }
            stopAgentBasedOnEntitlementCheckResult(result)
        }
    }

    private func satisfiesFreemiumPrerequisites() -> Bool {
        let isAuthenticated = authenticationManager.isUserAuthenticated
        let didActivateFreemium = freemiumDBPUserStateManager.didActivate
        return !isAuthenticated && didActivateFreemium
    }

    private func stopAgent() {
        stopAction.stopAgent()
    }

    private func stopAgentBasedOnEntitlementCheckResult(_ result: DataBrokerProtectionEntitlementMonitorResult) {
        switch result {
        case .enabled:
            Logger.dataBrokerProtection.log("Valid entitlement")
            pixelHandler.fire(.entitlementCheckValid)
        case .disabled:
            Logger.dataBrokerProtection.log("Invalid entitlement")
            pixelHandler.fire(.entitlementCheckInvalid)
            stopAgent()
        case .error:
            Logger.dataBrokerProtection.log("Error when checking entitlement")
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
        Logger.dataBrokerProtection.log("Stopping DataBrokerProtection Agent")
        exit(EXIT_SUCCESS)
    }
}
