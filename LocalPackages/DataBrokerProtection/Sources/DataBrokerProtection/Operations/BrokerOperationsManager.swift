//
//  BrokerOperationsManager.swift
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
     init(profileQuery: ProfileQuery, dataBroker: DataBroker, database: DataBase)

    func runScanOperation(on runner: OperationRunner) async throws
    func runOptOutOperation(for extractedProfile: ExtractedProfile, on runner: OperationRunner) async throws
}

/*
 This will run the operations
 Handle its data updates
 Expose its data for the Scheduler
 BrokerProfileQueryData being the main model
 */
class BrokerOperationsManager: OperationsManager {
    let brokerProfileQueryData: BrokerProfileQueryData
    let database: DataBase

    required init(profileQuery: ProfileQuery, dataBroker: DataBroker, database: DataBase) {
        self.database = database

        if let queryData = database.brokerProfileQueryData(for: profileQuery,
                                                           dataBroker: dataBroker) {
            brokerProfileQueryData = queryData
        } else {
            brokerProfileQueryData = BrokerProfileQueryData(id: UUID(),
                                                            profileQuery: profileQuery,
                                                            dataBroker: dataBroker)
        }
    }

    func runScanOperation(on runner: OperationRunner) async throws {

        do {
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

    func runOptOutOperation(for extractedProfile: ExtractedProfile, on runner: OperationRunner) async throws {
        guard let data = brokerProfileQueryData.optOutsData.filter({ $0.extractedProfile.id == extractedProfile.id }).first else {
            //TODO: Fix error, send pixel
            throw OperationsError.noOperationDataForExtractedProfile
        }


        do {
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

    private func saveExtractedProfiles(_ profiles: [ExtractedProfile]) {
        //TODO: Compare old and new profiles, set dateCreated on tem
        fatalError("no op")
    }

}

struct ExtractedProfileHandler {


    func getUniqueItems<T: Equatable>(newList: [T], oldList: [T]) -> [T] {
        var uniqueItems: [T] = []

        for item in newList {
            if !oldList.contains(item) {
                uniqueItems.append(item)
            }
        }

        return uniqueItems
    }

    /*

     func getUniqueItems<T: Equatable>(newList: [T], oldList: [T]) -> [T] {
         let oldSet = Set(oldList)
         var uniqueItems: [T] = []

         for item in newList {
             if !oldSet.contains(item) {
                 uniqueItems.append(item)
             }
         }

         return uniqueItems
     }

     */
}
