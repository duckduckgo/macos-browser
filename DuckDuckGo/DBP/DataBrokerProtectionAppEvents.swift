//
//  DataBrokerProtectionAppEvents.swift
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
import LoginItems
import Common
import DataBrokerProtection
import os.log

struct DataBrokerProtectionAppEvents {

    private let featureGatekeeper: DataBrokerProtectionFeatureGatekeeper
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let loginItemsManager: LoginItemsManaging
    private let loginItemInterface: DataBrokerProtectionLoginItemInterface

    enum WaitlistNotificationSource {
        case localPush
        case cardUI
    }

    init(featureGatekeeper: DataBrokerProtectionFeatureGatekeeper,
         pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler(),
         loginItemsManager: LoginItemsManaging = LoginItemsManager(),
         loginItemInterface: DataBrokerProtectionLoginItemInterface = DataBrokerProtectionManager.shared.loginItemInterface) {
        self.featureGatekeeper = featureGatekeeper
        self.pixelHandler = pixelHandler
        self.loginItemsManager = loginItemsManager
        self.loginItemInterface = loginItemInterface
    }

    func applicationDidFinishLaunching() {
        let loginItemsManager = LoginItemsManager()
        let loginItemInterface = DataBrokerProtectionManager.shared.loginItemInterface

        Task {
            // If we don't have profileQueries it means there's no user profile saved in our DB
            // In this case, let's disable the agent and delete any left-over data because there's nothing for it to do
            if let profileQueriesCount = try? DataBrokerProtectionManager.shared.dataManager.profileQueriesCount(),
               profileQueriesCount > 0 {
                Logger.dataBrokerProtection.log("Found \(profileQueriesCount) profile queries in DB. Restarting agent.")
                restartBackgroundAgent(loginItemsManager: loginItemsManager)

                // Wait to make sure the agent has had time to restart before attempting to call a method on it
                try await Task.sleep(nanoseconds: 1_000_000_000)
                loginItemInterface.appLaunched()
            }
        }

    }

    func applicationDidBecomeActive() {

        // Check feature prerequisites and disable the login item if they are not satisfied
        Task { @MainActor in
            let prerequisitesMet = await featureGatekeeper.arePrerequisitesSatisfied()
            guard prerequisitesMet else {
                loginItemsManager.disableLoginItems([LoginItem.dbpBackgroundAgent])
                return
            }
        }
    }

    private func restartBackgroundAgent(loginItemsManager: LoginItemsManager) {
        DataBrokerProtectionLoginItemPixels.fire(pixel: GeneralPixel.dataBrokerResetLoginItemDaily, frequency: .daily)
        loginItemsManager.disableLoginItems([LoginItem.dbpBackgroundAgent])
        loginItemsManager.enableLoginItems([LoginItem.dbpBackgroundAgent])

        // restartLoginItems doesn't work when we change the agent name
    }
}
