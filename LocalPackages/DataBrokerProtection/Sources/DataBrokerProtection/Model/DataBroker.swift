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

public struct DataBroker: Encodable, Sendable {
    let name: String
    let steps: [Step]
    let schedulingConfig: DataBrokerScheduleConfig = DataBrokerScheduleConfig(emailConfirmation: 10 * 60,
                                                                              retryError: 48 * 60,
                                                                              confirmScan: 72 * 60)

    enum CodingKeys: CodingKey {
        case name
        case steps
    }

    public init(name: String, steps: [Step]) {
        self.name = name
        self.steps = steps
    }

    func scanStep() throws -> Step {
        guard let scanStep = steps.first(where: { $0.type == .scan }) else {
            assertionFailure("Broker is missing the scan step.")
            throw DataBrokerProtectionError.unrecoverableError
        }

        return scanStep
    }
}

extension DataBroker: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public static func == (lhs: DataBroker, rhs: DataBroker) -> Bool {
        return lhs.name == rhs.name
    }
}
