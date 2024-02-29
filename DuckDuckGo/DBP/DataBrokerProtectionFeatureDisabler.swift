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

#if DBP

import Foundation
import DataBrokerProtection
import Common

public extension Notification.Name {
    static let dbpWasDisabled = Notification.Name("com.duckduckgo.DBP.DBPWasDisabled")
}

protocol DataBrokerProtectionFeatureDisabling {
    func disableAndDelete()
}

struct DataBrokerProtectionFeatureDisabler: DataBrokerProtectionFeatureDisabling {
    private let scheduler: DataBrokerProtectionLoginItemScheduler
    private let dataManager: InMemoryDataCacheDelegate
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>

    init(scheduler: DataBrokerProtectionLoginItemScheduler = DataBrokerProtectionManager.shared.scheduler,
         dataManager: InMemoryDataCacheDelegate = DataBrokerProtectionDataManager(),
         pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()) {
        self.dataManager = dataManager
        self.scheduler = scheduler
        self.pixelHandler = pixelHandler
    }

    func disableAndDelete() {
        if !DefaultDataBrokerProtectionFeatureVisibility.bypassWaitlist {
            scheduler.stopScheduler()

            scheduler.disableLoginItem()

            dataManager.removeAllData()

            pixelHandler.fire(.disableAndDelete)
            NotificationCenter.default.post(name: .dbpWasDisabled, object: nil)
        }
    }
}

#endif
