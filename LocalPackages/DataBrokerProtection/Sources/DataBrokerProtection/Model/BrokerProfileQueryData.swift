//
//  BrokerProfileQueryData.swift
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
import Common

public struct BrokerProfileQueryData: Sendable {
    let dataBroker: DataBroker
    let profileQuery: ProfileQuery
    let scanJobData: ScanJobData
    let optOutJobData: [OptOutJobData]

    var operationsData: [BrokerJobData] {
        optOutJobData + [scanJobData]
    }

    var extractedProfiles: [ExtractedProfile] {
        optOutJobData.map { $0.extractedProfile }
    }

    var events: [HistoryEvent] {
        operationsData.flatMap { $0.historyEvents }.sorted { $0.date < $1.date }
    }

    var hasMatches: Bool {
        !optOutJobData.isEmpty
    }

    init(dataBroker: DataBroker,
         profileQuery: ProfileQuery,
         scanJobData: ScanJobData,
         optOutJobData: [OptOutJobData] = [OptOutJobData]()) {
        self.profileQuery = profileQuery
        self.dataBroker = dataBroker
        self.scanJobData = scanJobData
        self.optOutJobData = optOutJobData
    }
}
