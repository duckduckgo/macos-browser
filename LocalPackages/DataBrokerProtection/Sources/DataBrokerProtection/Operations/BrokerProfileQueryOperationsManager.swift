//
//  BrokerProfileQueryOperationsManager.swift
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

enum OperationsError: Error {
    case noOperationDataForExtractedProfile
}

protocol OperationsManager {
    var brokerProfileQueryData: BrokerProfileQueryData { get }

    init(brokerProfileQueryData: BrokerProfileQueryData,
                  database: DataBase,
                  notificationCenter: NotificationCenter)

    func runScanOperation(on runner: OperationRunner) async throws
    func runOptOutOperation(for extractedProfile: ExtractedProfile, on runner: OperationRunner) async throws
    func runOptOutOperations(on runner: OperationRunner) async throws
}

class BrokerProfileQueryOperationsManager: OperationsManager {
    let brokerProfileQueryData: BrokerProfileQueryData
    let database: DataBase
    let notificationCenter: NotificationCenter

    required init(brokerProfileQueryData: BrokerProfileQueryData,
                  database: DataBase,
                  notificationCenter: NotificationCenter = NotificationCenter.default) {

        self.brokerProfileQueryData = brokerProfileQueryData
        self.notificationCenter = notificationCenter
        self.database = database
    }

    func runScanOperation(on runner: OperationRunner) async throws {
        defer {
            database.saveOperationData(brokerProfileQueryData.scanData)
            brokerProfileQueryData.scanData.lastRunDate = Date()
            notificationCenter.post(name: DataBrokerNotifications.didFinishScan, object: brokerProfileQueryData.dataBroker.name)
        }
        do {
            brokerProfileQueryData.addHistoryEvent(.init(type: .scanStarted), for: brokerProfileQueryData.scanData)

            let profiles = try await runner.scan(brokerProfileQueryData)

            if profiles.count > 0 {
                profiles.forEach {
                    let event = HistoryEvent(type: .matchFound(profileID: $0.id))
                    brokerProfileQueryData.addHistoryEvent(event, for: brokerProfileQueryData.scanData)
                }
            } else {
                let event = HistoryEvent(type: .noMatchFound)
                brokerProfileQueryData.addHistoryEvent(event, for: brokerProfileQueryData.scanData)
                
            }
            brokerProfileQueryData.updateExtractedProfiles(profiles)

        } catch {
            let event = HistoryEvent(type: .error)
            brokerProfileQueryData.addHistoryEvent(event, for: brokerProfileQueryData.scanData)
            print("ERROR \(error)")
            throw error
        }
    }

    func runOptOutOperations(on runner: OperationRunner) async throws {
        for extractedProfile in self.brokerProfileQueryData.extractedProfiles {
            try await runOptOutOperation(for: extractedProfile, on: runner)
        }
    }

    func runOptOutOperation(for extractedProfile: ExtractedProfile, on runner: OperationRunner) async throws {
        guard let data = brokerProfileQueryData.optOutsData.filter({ $0.extractedProfile.id == extractedProfile.id }).first else {
            //TODO: Fix error, send pixel
            throw OperationsError.noOperationDataForExtractedProfile
        }

        guard extractedProfile.removedDate == nil else {
            print("Profile already extracted")
            return
        }

        defer {
            database.saveOperationData(data)
            data.lastRunDate = Date()
            notificationCenter.post(name: DataBrokerNotifications.didFinishOptOut, object: brokerProfileQueryData.dataBroker.name)
        }

        do {
            brokerProfileQueryData.addHistoryEvent(.init(type: .optOutStarted(profileID: extractedProfile.id)), for: data)

            try await runner.optOut(extractedProfile)

            let event = HistoryEvent(type: .optOutRequested(profileID: extractedProfile.id))
            brokerProfileQueryData.addHistoryEvent(event, for: data)
        } catch {
            let event = HistoryEvent(type: .error)
            brokerProfileQueryData.addHistoryEvent(event, for: data)
            print("ERROR \(error)")
            throw error
        }

    }
}
