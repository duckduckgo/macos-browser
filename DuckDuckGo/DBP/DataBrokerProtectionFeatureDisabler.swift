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

protocol DataBrokerProtectionFeatureDisabling {
    func disableAndDelete()
}

struct DataBrokerProtectionFeatureDisabler: DataBrokerProtectionFeatureDisabling {
    private let scheduler: DataBrokerProtectionLoginItemScheduler
    private let dataManager: InMemoryDataCacheDelegate

    init(scheduler: DataBrokerProtectionLoginItemScheduler = DataBrokerProtectionManager.shared.scheduler,
         dataManager: InMemoryDataCacheDelegate = DataBrokerProtectionDataManager()) {
        self.dataManager = dataManager
        self.scheduler = scheduler
    }

    func disableAndDelete() {
        if !DefaultDataBrokerProtectionFeatureVisibility.shouldUseRedeemOnlyFlow {
            scheduler.stopScheduler()

            scheduler.disableLoginItem()

            dataManager.removeAllData()
        }
    }
}
