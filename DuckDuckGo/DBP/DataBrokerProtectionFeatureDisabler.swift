//
//  DataBrokerProtectionFeatureDisabler.swift
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
import DataBrokerProtection
import Common
import os.log

public extension Notification.Name {
    static let dbpWasDisabled = Notification.Name("com.duckduckgo.DBP.DBPWasDisabled")
}

protocol DataBrokerProtectionFeatureDisabling {
    func disableAndDelete()
}

struct DataBrokerProtectionFeatureDisabler: DataBrokerProtectionFeatureDisabling {
    private let loginItemInterface: DataBrokerProtectionLoginItemInterface
    private let dataManager: InMemoryDataCacheDelegate

    init(loginItemInterface: DataBrokerProtectionLoginItemInterface = DataBrokerProtectionManager.shared.loginItemInterface,
         dataManager: InMemoryDataCacheDelegate = DataBrokerProtectionManager.shared.dataManager) {
        self.dataManager = dataManager
        self.loginItemInterface = loginItemInterface
    }

    func disableAndDelete() {
        do {
            try dataManager.removeAllData()
            // the dataManagers delegate handles login item disabling
        } catch {
            Logger.dataBrokerProtection.error("DataBrokerProtectionFeatureDisabler error: disableAndDelete, error: \(error.localizedDescription, privacy: .public)")
        }

        DataBrokerProtectionLoginItemPixels.fire(pixel: GeneralPixel.dataBrokerDisableAndDeleteDaily, frequency: .daily)
        NotificationCenter.default.post(name: .dbpWasDisabled, object: nil)
    }
}
