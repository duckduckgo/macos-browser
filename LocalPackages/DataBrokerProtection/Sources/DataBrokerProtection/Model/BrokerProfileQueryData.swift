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

/*
 This is the profileQueryData
 It has a set of optOutOperationsData and a single scanOperationData
 */
class BrokerProfileQueryData {
    public let id: UUID
    public let profileQuery: ProfileQuery
    public let dataBroker: DataBroker

    public var extractedProfiles: [ExtractedProfile] = [ExtractedProfile]()
    public var scanData: ScanOperationData
    public var optOutsData: [OptOutOperationData] = [OptOutOperationData]()

    internal init(id: UUID,
                  profileQuery: ProfileQuery,
                  dataBroker: DataBroker,
                  extractedProfiles: [ExtractedProfile] = [ExtractedProfile](),
                  scanOperationData: ScanOperationData? = nil,
                  optOutOperationsData: [OptOutOperationData] = [OptOutOperationData]()) {

        self.id = id
        self.profileQuery = profileQuery
        self.dataBroker = dataBroker
        self.extractedProfiles = extractedProfiles
        self.optOutsData = optOutOperationsData

        if let scanData = scanOperationData {
            self.scanData = scanData
        } else {
            self.scanData = ScanOperationData(brokerProfileQueryID: id, preferredRunDate: Date(), historyEvents: [HistoryEvent]())
        }
    }

    func updateExtractedProfiles(_ extractedProfiles: [ExtractedProfile]) {
        self.extractedProfiles.append(contentsOf: extractedProfiles)
    }

    func addHistoryEvent(_ event: HistoryEvent, for operation: BrokerOperationData) {
        var op = operation
        op.addHistoryEvent(event)
    }
}
