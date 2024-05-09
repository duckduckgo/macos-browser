//
//  DataBrokerProtectionProcessorConfiguration.swift
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

struct DataBrokerProtectionProcessorConfiguration {
    // Arbitrary numbers for now
    let intervalBetweenSameBrokerOperations: TimeInterval = 2
    private let concurrentOperationsDifferentBrokers: Int = 2
    // https://app.asana.com/0/481882893211075/1206981742767469/f
    private let concurrentOperationsOnManualScans: Int = 6

    func concurrentOperationsFor(_ operation: OperationType) -> Int {
        switch operation {
        case .all, .optOut:
            return concurrentOperationsDifferentBrokers
        case .manualScan:
            return concurrentOperationsOnManualScans
        }
    }
}
