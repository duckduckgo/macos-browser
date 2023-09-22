//
//  UpdateChildSitesScanPreferredRunDate.swift
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

struct UpdateChildSitesScanPreferredRunDateUseCase {

    let database: DataBrokerProtectionRepository

    /// 1, This method fetches scan operations with the profileQueryId and with child sites of parentBrokerId
    /// 2. Then for each one it updates the preferredRunDate of the scan to its confirm scan
    func run(parentBroker: DataBroker, profileQueryId: Int64) {
        let childBrokers = database.fetchChildBrokers(for: parentBroker.name)

        childBrokers.forEach { childBroker in
            if let childBrokerId = childBroker.id {
                let confirmOptOutScanDate = Date().addingTimeInterval(childBroker.schedulingConfig.confirmOptOutScan.hoursToSeconds)
                database.updatePreferredRunDate(confirmOptOutScanDate,
                                                brokerId: childBrokerId,
                                                profileQueryId: profileQueryId)
            }
        }
    }
}
