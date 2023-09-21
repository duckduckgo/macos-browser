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
    case idsMissingForBrokerOrProfileQuery
}

protocol OperationsManager {

    // We want to refactor this to return a NSOperation in the future
    // so we have more control of stopping/starting the queue
    // for the time being, shouldRunNextStep: @escaping () -> Bool is being used
    func runOperation(operationData: BrokerOperationData,
                      brokerProfileQueryData: BrokerProfileQueryData,
                      database: DataBrokerProtectionRepository,
                      notificationCenter: NotificationCenter,
                      runner: WebOperationRunner,
                      pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                      showWebView: Bool,
                      shouldRunNextStep: @escaping () -> Bool) async throws
}

extension OperationsManager {
    func runOperation(operationData: BrokerOperationData,
                      brokerProfileQueryData: BrokerProfileQueryData,
                      database: DataBrokerProtectionRepository,
                      notificationCenter: NotificationCenter,
                      runner: WebOperationRunner,
                      pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                      shouldRunNextStep: @escaping () -> Bool) async throws {

        try await runOperation(operationData: operationData,
                               brokerProfileQueryData: brokerProfileQueryData,
                               database: database,
                               notificationCenter: notificationCenter,
                               runner: runner,
                               pixelHandler: pixelHandler,
                               showWebView: false,
                               shouldRunNextStep: shouldRunNextStep)
    }
}

struct DataBrokerProfileQueryOperationManager: OperationsManager {

    internal func runOperation(operationData: BrokerOperationData,
                               brokerProfileQueryData: BrokerProfileQueryData,
                               database: DataBrokerProtectionRepository,
                               notificationCenter: NotificationCenter = NotificationCenter.default,
                               runner: WebOperationRunner,
                               pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                               showWebView: Bool = false,
                               shouldRunNextStep: @escaping () -> Bool) async throws {

        if operationData as? ScanOperationData != nil {
            try await runScanOperation(on: runner,
                                       brokerProfileQueryData: brokerProfileQueryData,
                                       database: database,
                                       notificationCenter: notificationCenter,
                                       pixelHandler: pixelHandler,
                                       showWebView: showWebView,
                                       shouldRunNextStep: shouldRunNextStep)
        } else if let optOutOperationData = operationData as? OptOutOperationData {
            try await runOptOutOperation(for: optOutOperationData.extractedProfile,
                                         on: runner,
                                         brokerProfileQueryData: brokerProfileQueryData,
                                         database: database,
                                         notificationCenter: notificationCenter,
                                         pixelHandler: pixelHandler,
                                         showWebView: showWebView,
                                         shouldRunNextStep: shouldRunNextStep)
        }
    }

    // swiftlint:disable:next function_body_length
    internal func runScanOperation(on runner: WebOperationRunner,
                                   brokerProfileQueryData: BrokerProfileQueryData,
                                   database: DataBrokerProtectionRepository,
                                   notificationCenter: NotificationCenter,
                                   pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                                   showWebView: Bool = false,
                                   shouldRunNextStep: @escaping () -> Bool) async throws {
        os_log("Running scan operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

        guard let brokerId = brokerProfileQueryData.dataBroker.id, let profileQueryId = brokerProfileQueryData.profileQuery.id else {
            // Maybe send pixel?
            throw OperationsError.idsMissingForBrokerOrProfileQuery
        }

        defer {
            database.updateLastRunDate(Date(), brokerId: brokerId, profileQueryId: profileQueryId)
            updateOperationDataDates(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: nil,
                schedulingConfig: brokerProfileQueryData.dataBroker.schedulingConfig,
                database: database
            )
            os_log("Finished scan operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))
            notificationCenter.post(name: DataBrokerProtectionNotifications.didFinishScan, object: brokerProfileQueryData.dataBroker.name)
        }

        do {
            let event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .scanStarted)
            database.add(event)
            let stageCalculator = DataBrokerProtectionStageDurationCalculator(dataBroker: brokerProfileQueryData.dataBroker.name, handler: pixelHandler)
            let extractedProfiles = try await runner.scan(brokerProfileQueryData, stageCalculator: stageCalculator, showWebView: showWebView, shouldRunNextStep: shouldRunNextStep)
            os_log("Extracted profiles: %@", log: .dataBrokerProtection, extractedProfiles)

            if !extractedProfiles.isEmpty {
                let event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .matchesFound)
                database.add(event)

                for extractedProfile in extractedProfiles {

                    // We check if the profile exists in the database.
                    let extractedProfilesForBroker = database.fetchExtractedProfiles(for: brokerId)
                    let doesProfileExistsInDatabase = extractedProfilesForBroker.contains { $0.profileUrl == extractedProfile.profileUrl }

                    // If the profile exists we do not create a new opt-out operation
                    if doesProfileExistsInDatabase, let alreadyInDatabaseProfile = extractedProfilesForBroker.first(where: { $0.profileUrl == extractedProfile.profileUrl }), let id = alreadyInDatabaseProfile.id {
                        // If it was removed in the past but was found again when scanning, it means it appearead again, so we reset the remove date.
                        if alreadyInDatabaseProfile.removedDate != nil {
                            database.updateRemovedDate(nil, on: id)
                        }

                        os_log("Extracted profile already exists in database: %@", log: .dataBrokerProtection, id.description)
                    } else {
                        // If profile does not exist we insert the new profile and we create the opt-out operation
                        //
                        // This is done inside a transaction on the database side. We insert the extracted profile and then
                        // we insert the opt-out operation, we do not want to do things separately in case creating an opt-out fails
                        // causing the extracted profile to be orphan.
                        let optOutOperationData = OptOutOperationData(brokerId: brokerId,
                                                                      profileQueryId: profileQueryId,
                                                                      preferredRunDate: Date(), // If it's a new found profile, we'd like to opt-out ASAP
                                                                      historyEvents: [HistoryEvent](),
                                                                      extractedProfile: extractedProfile)
                        os_log("Creating new opt-out operation data for: %@", log: .dataBrokerProtection, String(describing: extractedProfile.name))
                        try database.saveOptOutOperation(optOut: optOutOperationData, extractedProfile: extractedProfile)
                    }
                }
            } else {
                let event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .noMatchFound)
                database.add(event)
            }

            // Check for removed profiles
            let removedProfiles = brokerProfileQueryData.extractedProfiles.filter { savedProfile in
                !extractedProfiles.contains { recentlyFoundProfile in
                    recentlyFoundProfile.profileUrl == savedProfile.profileUrl
                }
            }

            for removedProfile in removedProfiles {
                if let extractedProfileId = removedProfile.id {
                    let event = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutConfirmed)
                    database.add(event)
                    database.updateRemovedDate(Date(), on: extractedProfileId)
                    database.updatePreferredRunDate(Date(), brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
                    os_log("Profile removed from optOutsData: %@", log: .dataBrokerProtection, String(describing: removedProfile))

                    // Add a comment explaining this piece of code
                    if let attempt = database.fetchAttemptInformation(for: extractedProfileId), let attemptUUID = UUID(uuidString: attempt.attemptId) {
                        let now = Date()
                        let calculateDurationSinceLastStage = now.timeIntervalSince(attempt.lastStageDate) * 1000
                        let calculateDurationSinceStart = now.timeIntervalSince(attempt.startDate) * 1000
                        pixelHandler.fire(.optOutFinish(dataBroker: attempt.dataBroker, attemptId: attemptUUID, duration: calculateDurationSinceLastStage))
                        pixelHandler.fire(.optOutSuccess(dataBroker: attempt.dataBroker, attemptId: attemptUUID, duration: calculateDurationSinceStart))
                    }
                }
            }

        } catch {
            handleOperationError(brokerId: brokerId,
                                 profileQueryId: profileQueryId,
                                 extractedProfileId: nil,
                                 error: error,
                                 database: database)
            throw error
        }
    }

    internal func runOptOutOperation(for extractedProfile: ExtractedProfile,
                                     on runner: WebOperationRunner,
                                     brokerProfileQueryData: BrokerProfileQueryData,
                                     database: DataBrokerProtectionRepository,
                                     notificationCenter: NotificationCenter,
                                     pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                                     showWebView: Bool = false,
                                     shouldRunNextStep: @escaping () -> Bool) async throws {
        guard let brokerId = brokerProfileQueryData.dataBroker.id, let profileQueryId = brokerProfileQueryData.profileQuery.id, let extractedProfileId = extractedProfile.id else {
            // Maybe send pixel?
            throw OperationsError.idsMissingForBrokerOrProfileQuery
        }

        guard extractedProfile.removedDate == nil else {
            os_log("Profile already extracted, skipping...", log: .dataBrokerProtection)
            return
        }

        let stageDurationCalculator = DataBrokerProtectionStageDurationCalculator(dataBroker: brokerProfileQueryData.dataBroker.name, handler: pixelHandler)
        stageDurationCalculator.fireOptOutStart()
        os_log("Running opt-out operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

        defer {
            os_log("Finished opt-out operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

            database.updateLastRunDate(Date(), brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
            updateOperationDataDates(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId,
                schedulingConfig: brokerProfileQueryData.dataBroker.schedulingConfig,
                database: database
            )
            notificationCenter.post(name: DataBrokerProtectionNotifications.didFinishOptOut, object: brokerProfileQueryData.dataBroker.name)
        }

        do {
            database.add(.init(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutStarted))

            try await runner.optOut(profileQuery: brokerProfileQueryData,
                                    extractedProfile: extractedProfile,
                                    stageCalculator: stageDurationCalculator,
                                    showWebView: showWebView,
                                    shouldRunNextStep: shouldRunNextStep)

            database.addAttempt(extractedProfileId: extractedProfileId,
                                attemptUUID: stageDurationCalculator.attemptId,
                                dataBroker: stageDurationCalculator.dataBroker,
                                lastStageDate: stageDurationCalculator.lastStateTime,
                                startTime: stageDurationCalculator.startTime)
            database.add(.init(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested))
        } catch {
            stageDurationCalculator.fireOptOutFailure()
            handleOperationError(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId,
                error: error,
                database: database
            )
            throw error
        }
    }

    // https://app.asana.com/0/0/1204834439855281/f
    // swiftlint:disable:next function_body_length
    internal func updateOperationDataDates(
        brokerId: Int64,
        profileQueryId: Int64,
        extractedProfileId: Int64?,
        schedulingConfig: DataBrokerScheduleConfig,
        database: DataBrokerProtectionRepository
    ) {
        let maintenanceScanDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)

        if let brokerProfileQuery = database.brokerProfileQueryData(for: brokerId, and: profileQueryId),
           let lastHistoryEvent = brokerProfileQuery.events.last {
            switch lastHistoryEvent.type {
            case .error:
                let retryOperationDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)
                updatePreferredRunDate(
                    retryOperationDate,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: extractedProfileId,
                    database: database
                )
            case .optOutRequested:
                let confirmOptOutDate = Date().addingTimeInterval(schedulingConfig.confirmOptOutScan.hoursToSeconds)

                // We set extractedProfileId to nil because we want to update the scan operation
                updatePreferredRunDate(
                    confirmOptOutDate,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: nil,
                    database: database
                )
                // For the optOut operation we set it to nil. We do not want to run it again
                updatePreferredRunDate(
                    nil,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: extractedProfileId,
                    database: database
                )
            case .matchesFound:
                updatePreferredRunDate(
                    maintenanceScanDate,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: nil,
                    database: database
                )

                if let extractedProfileId = extractedProfileId,
                   shouldScheduleNewOptOut(
                    events: brokerProfileQuery.events,
                    extractedProfileId: extractedProfileId,
                    schedulingConfig: schedulingConfig
                   ) {
                    updatePreferredRunDate(
                        Date(),
                        brokerId: brokerId,
                        profileQueryId: profileQueryId,
                        extractedProfileId: extractedProfileId,
                        database: database
                    )
                } else {
                    if extractedProfileId == nil {
                        updatePreferredRunDate(
                            maintenanceScanDate,
                            brokerId: brokerId,
                            profileQueryId: profileQueryId,
                            extractedProfileId: nil,
                            database: database
                        )
                    }
                }
            case .noMatchFound, .optOutConfirmed:
                // We set extractedProfileId to nil because we want to update the scan operation
                updatePreferredRunDate(
                    maintenanceScanDate,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: nil,
                    database: database
                )

                // We make sure the optOut operation is set to nil. It should be nil from the optOutRequested.
                updatePreferredRunDate(
                    nil,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: extractedProfileId,
                    database: database
                )
            case .optOutStarted, .scanStarted:
                // We don't need to update the dates when we have these statuses
                // This is added to ensure that the compiler can detect any new enums added in the future
                break
            }
        }
    }

    private func updatePreferredRunDate(
        _ date: Date?,
        brokerId: Int64,
        profileQueryId: Int64,
        extractedProfileId: Int64?,
        database: DataBrokerProtectionRepository
    ) {
        if  let extractedProfileId = extractedProfileId {
            database.updatePreferredRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
        } else {
            database.updatePreferredRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId)
        }

        os_log("Updating preferredRunDate on operation with brokerId %{public}@ and profileQueryId %{public}@", log: .dataBrokerProtection, brokerId.description, profileQueryId.description)
    }

    private func handleOperationError(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64?, error: Error, database: DataBrokerProtectionRepository) {
        let event: HistoryEvent

        if let extractedProfileId = extractedProfileId {
            if let error = error as? DataBrokerProtectionError {
                event = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .error(error: error))
            } else {
                event = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .error(error: .unknown(error.localizedDescription)))
            }
        } else {
            if let error = error as? DataBrokerProtectionError {
                event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .error(error: error))
            } else {
                event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .error(error: .unknown(error.localizedDescription)))
            }
        }

        database.add(event)

        os_log("Error on operation : %{public}@", log: .dataBrokerProtection, error.localizedDescription)
    }

    // If the last time we removed the profile has a bigger time difference than the current date + maintenance we should schedule for a new optout
    private func shouldScheduleNewOptOut(events: [HistoryEvent],
                                         extractedProfileId: Int64,
                                         schedulingConfig: DataBrokerScheduleConfig) -> Bool {
        guard let lastRemovalEvent = events.last(where: { $0.type == .optOutRequested && $0.extractedProfileId == extractedProfileId }) else {
            return false
        }

        return lastRemovalEvent.date.addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds) < Date()
    }
}
