//
//  DataBroker.swift
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

struct DataBrokerScheduleConfig {
    let emailConfirmation: TimeInterval
    let retryError: TimeInterval
    let confirmScan: TimeInterval
}

struct DataBroker {
    let name: String
    let schedulingConfig: DataBrokerScheduleConfig

    internal init(name: String) {
        self.name = name
        self.schedulingConfig = DataBrokerScheduleConfig(emailConfirmation: 10 * 60,
                                                         retryError: 48 * 60,
                                                         confirmScan: 72 * 60)
    }

}

extension DataBroker: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func ==(lhs: DataBroker, rhs: DataBroker) -> Bool {
        return lhs.name == rhs.name
    }
}
