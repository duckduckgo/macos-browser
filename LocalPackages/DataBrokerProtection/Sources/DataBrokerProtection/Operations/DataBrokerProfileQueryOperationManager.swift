//
//  DataBrokerProfileQueryOperationManager.swift
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

enum OperationsError: Error {
    case noOperationDataForExtractedProfile
}

protocol OperationsManager {
    func runOperation(operationData: BrokerOperationData,
                      brokerProfileQueryData: BrokerProfileQueryData,
                      database: DataBase,
                      notificationCenter: NotificationCenter,
                      runner: WebOperationRunner) async throws
}

struct DataBrokerProfileQueryOperationManager: OperationsManager {

    internal func runOperation(operationData: BrokerOperationData,
                               brokerProfileQueryData: BrokerProfileQueryData,
                               database: DataBase,
                               notificationCenter: NotificationCenter = NotificationCenter.default,
                               runner: WebOperationRunner) async throws {

        if operationData as? ScanOperationData != nil {
            try await runScanOperation(on: runner,
                                       brokerProfileQueryData: brokerProfileQueryData,
                                       database: database,
                                       notificationCenter: notificationCenter)

        } else if let optOutOperationData = operationData as? OptOutOperationData {
            try await runOptOutOperation(for: optOutOperationData.extractedProfile,
                                         on: runner,
                                         brokerProfileQueryData: brokerProfileQueryData,
                                         database: database,
                                         notificationCenter: notificationCenter)
        }
    }

    // https://app.asana.com/0/0/1204834439855281/f
    // swiftlint:disable:next cyclomatic_complexity
    private func updateOperationDataDates(_ operationData: BrokerOperationData,
                                          brokerProfileQueryData: BrokerProfileQueryData) {
        var data = operationData
        data.lastRunDate = Date()

        let optOutData = operationData as? OptOutOperationData
        var scanData = operationData as? ScanOperationData

        // If we're setting an optOut date we might need to update the scan date as well
        if scanData == nil {
            scanData = brokerProfileQueryData.scanData
        }

        let maintenanceScanDate = Date().addingTimeInterval(brokerProfileQueryData.dataBroker.schedulingConfig.maintenanceScan)

        if let lastHistoryEvent = data.historyEvents.last {
            switch lastHistoryEvent.type {
            case .error:
                let newDate = Date().addingTimeInterval(brokerProfileQueryData.dataBroker.schedulingConfig.retryError)
                updatePreferredRunDate(newDate, on: data)

            case .optOutRequested:
                optOutData?.preferredRunDate = nil
                let newDate = Date().addingTimeInterval(brokerProfileQueryData.dataBroker.schedulingConfig.confirmOptOutScan)
                if let scanData = scanData {
                    updatePreferredRunDate(newDate, on: scanData)
                }

            case .matchFound:
                if let optOutData = optOutData, shouldScheduleNewOptOut(operationData: optOutData,
                                                                        brokerProfileQueryData: brokerProfileQueryData) {
                    updatePreferredRunDate(Date(), on: optOutData)
                } else {
                    if let scanData = scanData {
                        updatePreferredRunDate(maintenanceScanDate, on: scanData)
                    }
                }

            case .noMatchFound, .optOutConfirmed:
                if let scanData = scanData {
                    updatePreferredRunDate(maintenanceScanDate, on: scanData)
                }
                optOutData?.preferredRunDate = nil

            case .optOutStarted, .scanStarted:
                // We don't need to update the dates when we have these statuses
                // This is added to ensure that the compiler can detect any new enums added in the future
                break
            }
        }
    }

    private func updatePreferredRunDate(_ date: Date, on data: BrokerOperationData) {
        var data = data

        if data.preferredRunDate == nil || data.preferredRunDate! > date {
            data.preferredRunDate = date
            os_log("Updating preferredRunDate on %@", log: .dataBrokerProtection, data.id.uuidString)

        }
    }

    private func handleOperationError(brokerProfileQuery: BrokerProfileQueryData, operationData: BrokerOperationData, error: Error) {
        let event = HistoryEvent(type: .error)
        brokerProfileQuery.addHistoryEvent(event, for: operationData)
        // TODO: Send error pixel
        os_log("Error : %{public}@", log: .dataBrokerProtection, error.localizedDescription)

    }

    // If the last time we removed the profile has a bigger time difference than the current date + maintenance we should schedule for a new optout
    private func shouldScheduleNewOptOut(operationData: OptOutOperationData,
                                         brokerProfileQueryData: BrokerProfileQueryData) -> Bool {
        guard let lastRemovalEvent = operationData.lastEventWith(type: .optOutRequested(extractedProfileID: operationData.extractedProfile.id)) else {
            return false
        }
        return lastRemovalEvent.date.addingTimeInterval(brokerProfileQueryData.dataBroker.schedulingConfig.maintenanceScan) < Date()
    }

    private func runScanOperation(on runner: WebOperationRunner,
                                  brokerProfileQueryData: BrokerProfileQueryData,
                                  database: DataBase,
                                  notificationCenter: NotificationCenter) async throws {
        defer {
            updateOperationDataDates(brokerProfileQueryData.scanData,
                                     brokerProfileQueryData: brokerProfileQueryData)
            database.saveOperationData(brokerProfileQueryData.scanData)
            os_log("Finished scan operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))
            notificationCenter.post(name: DataBrokerProtectionNotifications.didFinishScan, object: brokerProfileQueryData.dataBroker.name)
        }
        os_log("Running scan operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

        do {
            brokerProfileQueryData.scanData.addHistoryEvent(.init(type: .scanStarted))

            // Clean preferredRunDate when the operation runs
            brokerProfileQueryData.scanData.preferredRunDate = nil

            let profiles = try await runner.scan(brokerProfileQueryData)
            os_log("Extracted profiles: %@", log: .dataBrokerProtection, profiles)

            if !profiles.isEmpty {
                profiles.forEach {
                    let event = HistoryEvent(type: .matchFound(extractedProfileID: $0.id))
                    brokerProfileQueryData.scanData.addHistoryEvent(event)
                }
            } else {
                let event = HistoryEvent(type: .noMatchFound)
                brokerProfileQueryData.scanData.addHistoryEvent(event)

            }
            brokerProfileQueryData.updateExtractedProfiles(profiles)

        } catch {
            handleOperationError(brokerProfileQuery: brokerProfileQueryData,
                                 operationData: brokerProfileQueryData.scanData,
                                 error: error)
            throw error
        }
    }

    internal func runOptOutOperation(for extractedProfile: ExtractedProfile,
                                     on runner: WebOperationRunner,
                                     brokerProfileQueryData: BrokerProfileQueryData,
                                     database: DataBase,
                                     notificationCenter: NotificationCenter) async throws {

        guard let data = brokerProfileQueryData.optOutsData.filter({ $0.extractedProfile.id == extractedProfile.id }).first else {
            // TODO: Fix error, send pixel
            throw OperationsError.noOperationDataForExtractedProfile
        }

        guard extractedProfile.removedDate == nil else {
            os_log("Profile already extracted, skipping...", log: .dataBrokerProtection)
            return
        }

        os_log("Running opt-out operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

        defer {
            os_log("Finished opt-out operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

            updateOperationDataDates(data, brokerProfileQueryData: brokerProfileQueryData)
            updateOperationDataDates(brokerProfileQueryData.scanData, brokerProfileQueryData: brokerProfileQueryData)
            database.saveOperationData(data)
            notificationCenter.post(name: DataBrokerProtectionNotifications.didFinishOptOut, object: brokerProfileQueryData.dataBroker.name)
        }

        do {
            brokerProfileQueryData.addHistoryEvent(.init(type: .optOutStarted(extractedProfileID: extractedProfile.id)), for: data)
            // Clean preferredRunDate when the operation runs
            data.preferredRunDate = nil

            try await runner.optOut(profileQuery: brokerProfileQueryData, extractedProfile: extractedProfile)

            let event = HistoryEvent(type: .optOutRequested(extractedProfileID: extractedProfile.id))
            brokerProfileQueryData.addHistoryEvent(event, for: data)
        } catch {
            handleOperationError(brokerProfileQuery: brokerProfileQueryData,
                                 operationData: data,
                                 error: error)
            throw error
        }

    }
}
