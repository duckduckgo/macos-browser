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

struct DataBrokerScheduleConfig: Codable {
    let retryError: TimeInterval
    let confirmOptOutScan: TimeInterval
    let maintenanceScan: TimeInterval
}

struct DataBroker: Codable, Sendable {
    let id = UUID()
    let name: String
    let steps: [Step]
    let schedulingConfig: DataBrokerScheduleConfig

    var isFakeBroker: Bool {
        name.contains("fake") // A future improvement will be to add a property in the JSON file.
    }

    enum CodingKeys: CodingKey {
        case name
        case steps
        case schedulingConfig
    }

    init(name: String, steps: [Step], schedulingConfig: DataBrokerScheduleConfig) {
        self.name = name
        self.steps = steps
        self.schedulingConfig = schedulingConfig
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        steps = try container.decode([Step].self, forKey: .steps)
        schedulingConfig = try container.decode(DataBrokerScheduleConfig.self, forKey: .schedulingConfig)
    }

    func scanStep() throws -> Step {
        guard let scanStep = steps.first(where: { $0.type == .scan }) else {
            assertionFailure("Broker is missing the scan step.")
            throw DataBrokerProtectionError.unrecoverableError
        }

        return scanStep
    }

    func optOutStep() throws -> Step? {
        guard let optOutStep = steps.first(where: { $0.type == .optOut }) else {
            return nil
        }

        return optOutStep
    }

    static func initFromResource(_ brokerName: String) -> DataBroker {
        let jsonUrl = Bundle.module.url(forResource: brokerName, withExtension: "json")!
        // swiftlint:disable:next force_try
        let data = try! Data(contentsOf: jsonUrl)
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(DataBroker.self, from: data)
    }
}

extension DataBroker: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: DataBroker, rhs: DataBroker) -> Bool {
        return lhs.name == rhs.name
    }
}
