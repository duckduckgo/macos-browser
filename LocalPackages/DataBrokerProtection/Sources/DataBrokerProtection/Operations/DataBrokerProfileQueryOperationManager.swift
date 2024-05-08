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
                      runner: WebJobRunner,
                      pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                      showWebView: Bool,
                      isManualScan: Bool,
                      userNotificationService: DataBrokerProtectionUserNotificationService,
                      shouldRunNextStep: @escaping () -> Bool) async throws
}

extension OperationsManager {
    func runOperation(operationData: BrokerOperationData,
                      brokerProfileQueryData: BrokerProfileQueryData,
                      database: DataBrokerProtectionRepository,
                      notificationCenter: NotificationCenter,
                      runner: WebJobRunner,
                      pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                      userNotificationService: DataBrokerProtectionUserNotificationService,
                      isManual: Bool,
                      shouldRunNextStep: @escaping () -> Bool) async throws {

        try await runOperation(operationData: operationData,
                               brokerProfileQueryData: brokerProfileQueryData,
                               database: database,
                               notificationCenter: notificationCenter,
                               runner: runner,
                               pixelHandler: pixelHandler,
                               showWebView: false,
                               isManualScan: isManual,
                               userNotificationService: userNotificationService,
                               shouldRunNextStep: shouldRunNextStep)
    }
}

struct DataBrokerProfileQueryOperationManager: OperationsManager {

    internal func runOperation(operationData: BrokerOperationData,
                               brokerProfileQueryData: BrokerProfileQueryData,
                               database: DataBrokerProtectionRepository,
                               notificationCenter: NotificationCenter = NotificationCenter.default,
                               runner: WebJobRunner,
                               pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                               showWebView: Bool = false,
                               isManualScan: Bool = false,
                               userNotificationService: DataBrokerProtectionUserNotificationService,
                               shouldRunNextStep: @escaping () -> Bool) async throws {

        if operationData as? ScanOperationData != nil {
            try await runScanOperation(on: runner,
                                       brokerProfileQueryData: brokerProfileQueryData,
                                       database: database,
                                       notificationCenter: notificationCenter,
                                       pixelHandler: pixelHandler,
                                       showWebView: showWebView,
                                       isManual: isManualScan,
                                       userNotificationService: userNotificationService,
                                       shouldRunNextStep: shouldRunNextStep)
        } else if let optOutOperationData = operationData as? OptOutOperationData {
            try await runOptOutOperation(for: optOutOperationData.extractedProfile,
                                         on: runner,
                                         brokerProfileQueryData: brokerProfileQueryData,
                                         database: database,
                                         notificationCenter: notificationCenter,
                                         pixelHandler: pixelHandler,
                                         showWebView: showWebView,
                                         userNotificationService: userNotificationService,
                                         shouldRunNextStep: shouldRunNextStep)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func runScanOperation(on runner: WebJobRunner,
                                   brokerProfileQueryData: BrokerProfileQueryData,
                                   database: DataBrokerProtectionRepository,
                                   notificationCenter: NotificationCenter,
                                   pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                                   showWebView: Bool = false,
                                   isManual: Bool = false,
                                   userNotificationService: DataBrokerProtectionUserNotificationService,
                                   shouldRunNextStep: @escaping () -> Bool) async throws {
        os_log("Running scan operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

        guard let brokerId = brokerProfileQueryData.dataBroker.id, let profileQueryId = brokerProfileQueryData.profileQuery.id else {
            // Maybe send pixel?
            throw OperationsError.idsMissingForBrokerOrProfileQuery
        }

        defer {
            try? database.updateLastRunDate(Date(), brokerId: brokerId, profileQueryId: profileQueryId)
            os_log("Finished scan operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))
            notificationCenter.post(name: DataBrokerProtectionNotifications.didFinishScan, object: brokerProfileQueryData.dataBroker.name)
        }

        let eventPixels = DataBrokerProtectionEventPixels(database: database, handler: pixelHandler)
        let stageCalculator = DataBrokerProtectionStageDurationCalculator(dataBroker: brokerProfileQueryData.dataBroker.name,
                                                                          handler: pixelHandler,
                                                                          isManualScan: isManual)

        do {
            let event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .scanStarted)
            try database.add(event)

            let extractedProfiles = try await runner.scan(brokerProfileQueryData, stageCalculator: stageCalculator, pixelHandler: pixelHandler, showWebView: showWebView, shouldRunNextStep: shouldRunNextStep)
            os_log("Extracted profiles: %@", log: .dataBrokerProtection, extractedProfiles)

            if !extractedProfiles.isEmpty {
                stageCalculator.fireScanSuccess(matchesFound: extractedProfiles.count)
                let event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .matchesFound(count: extractedProfiles.count))
                try database.add(event)

                for extractedProfile in extractedProfiles {

                    // We check if the profile exists in the database.
                    let extractedProfilesForBroker = try database.fetchExtractedProfiles(for: brokerId)
                    let doesProfileExistsInDatabase = extractedProfilesForBroker.contains { $0.identifier == extractedProfile.identifier }

                    // If the profile exists we do not create a new opt-out operation
                    if doesProfileExistsInDatabase, let alreadyInDatabaseProfile = extractedProfilesForBroker.first(where: { $0.identifier == extractedProfile.identifier }), let id = alreadyInDatabaseProfile.id {
                        // If it was removed in the past but was found again when scanning, it means it appearead again, so we reset the remove date.
                        if alreadyInDatabaseProfile.removedDate != nil {
                            let reAppereanceEvent = HistoryEvent(extractedProfileId: extractedProfile.id, brokerId: brokerId, profileQueryId: profileQueryId, type: .reAppearence)
                            eventPixels.fireReAppereanceEventPixel()
                            try database.add(reAppereanceEvent)
                            try database.updateRemovedDate(nil, on: id)
                        }

                        os_log("Extracted profile already exists in database: %@", log: .dataBrokerProtection, id.description)
                    } else {
                        // If it's a new found profile, we'd like to opt-out ASAP
                        // If this broker has a parent opt out, we set the preferred date to nil, as we will only perform the operation within the parent.
                        eventPixels.fireNewMatchEventPixel()
                        let broker = brokerProfileQueryData.dataBroker
                        let preferredRunOperation: Date? = broker.performsOptOutWithinParent() ? nil : Date()

                        // If profile does not exist we insert the new profile and we create the opt-out operation
                        //
                        // This is done inside a transaction on the database side. We insert the extracted profile and then
                        // we insert the opt-out operation, we do not want to do things separately in case creating an opt-out fails
                        // causing the extracted profile to be orphan.
                        let optOutOperationData = OptOutOperationData(brokerId: brokerId,
                                                                      profileQueryId: profileQueryId,
                                                                      preferredRunDate: preferredRunOperation,
                                                                      historyEvents: [HistoryEvent](),
                                                                      extractedProfile: extractedProfile)

                        try database.saveOptOutOperation(optOut: optOutOperationData, extractedProfile: extractedProfile)

                        os_log("Creating new opt-out operation data for: %@", log: .dataBrokerProtection, String(describing: extractedProfile.name))
                    }
                }
            } else {
                stageCalculator.fireScanFailed()
                let event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .noMatchFound)
                try database.add(event)
            }

            // Check for removed profiles
            let removedProfiles = brokerProfileQueryData.extractedProfiles.filter { savedProfile in
                !extractedProfiles.contains { recentlyFoundProfile in
                    recentlyFoundProfile.identifier == savedProfile.identifier
                }
            }

            if !removedProfiles.isEmpty {
                var shouldSendProfileRemovedNotification = false
                for removedProfile in removedProfiles {
                    if let extractedProfileId = removedProfile.id {
                        let event = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutConfirmed)
                        try database.add(event)
                        try database.updateRemovedDate(Date(), on: extractedProfileId)
                        shouldSendProfileRemovedNotification = true
                        try updateOperationDataDates(
                            origin: .scan,
                            brokerId: brokerId,
                            profileQueryId: profileQueryId,
                            extractedProfileId: extractedProfileId,
                            schedulingConfig: brokerProfileQueryData.dataBroker.schedulingConfig,
                            database: database
                        )

                        os_log("Profile removed from optOutsData: %@", log: .dataBrokerProtection, String(describing: removedProfile))

                        if let attempt = try database.fetchAttemptInformation(for: extractedProfileId), let attemptUUID = UUID(uuidString: attempt.attemptId) {
                            let now = Date()
                            let calculateDurationSinceLastStage = now.timeIntervalSince(attempt.lastStageDate) * 1000
                            let calculateDurationSinceStart = now.timeIntervalSince(attempt.startDate) * 1000
                            pixelHandler.fire(.optOutFinish(dataBroker: attempt.dataBroker, attemptId: attemptUUID, duration: calculateDurationSinceLastStage))
                            pixelHandler.fire(.optOutSuccess(dataBroker: attempt.dataBroker, attemptId: attemptUUID, duration: calculateDurationSinceStart, brokerType: brokerProfileQueryData.dataBroker.type))
                        }
                    }
                }
                if shouldSendProfileRemovedNotification {
                    sendProfileRemovedNotificationIfNecessary(userNotificationService: userNotificationService,
                                                              database: database)
                }
            } else {
                try updateOperationDataDates(
                    origin: .scan,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: nil,
                    schedulingConfig: brokerProfileQueryData.dataBroker.schedulingConfig,
                    database: database
                )
            }

        } catch {
            stageCalculator.fireScanError(error: error)
            handleOperationError(origin: .scan,
                                 brokerId: brokerId,
                                 profileQueryId: profileQueryId,
                                 extractedProfileId: nil,
                                 error: error,
                                 database: database,
                                 schedulingConfig: brokerProfileQueryData.dataBroker.schedulingConfig)
            throw error
        }
    }

    private func sendProfileRemovedNotificationIfNecessary(userNotificationService: DataBrokerProtectionUserNotificationService, database: DataBrokerProtectionRepository) {

        guard let savedExtractedProfiles = try? database.fetchAllBrokerProfileQueryData().flatMap({ $0.extractedProfiles }),
            savedExtractedProfiles.count > 0 else {
            return
        }

        if savedExtractedProfiles.count == 1 {
            userNotificationService.sendAllInfoRemovedNotificationIfPossible()
        } else {
            if savedExtractedProfiles.allSatisfy({ $0.removedDate != nil }) {
                userNotificationService.sendAllInfoRemovedNotificationIfPossible()
            } else {
                userNotificationService.sendFirstRemovedNotificationIfPossible()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    internal func runOptOutOperation(for extractedProfile: ExtractedProfile,
                                     on runner: WebJobRunner,
                                     brokerProfileQueryData: BrokerProfileQueryData,
                                     database: DataBrokerProtectionRepository,
                                     notificationCenter: NotificationCenter,
                                     pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                                     showWebView: Bool = false,
                                     userNotificationService: DataBrokerProtectionUserNotificationService,
                                     shouldRunNextStep: @escaping () -> Bool) async throws {
        guard let brokerId = brokerProfileQueryData.dataBroker.id, let profileQueryId = brokerProfileQueryData.profileQuery.id, let extractedProfileId = extractedProfile.id else {
            // Maybe send pixel?
            throw OperationsError.idsMissingForBrokerOrProfileQuery
        }

        guard extractedProfile.removedDate == nil else {
            os_log("Profile already extracted, skipping...", log: .dataBrokerProtection)
            return
        }

        guard let optOutStep = brokerProfileQueryData.dataBroker.optOutStep(), optOutStep.optOutType != .parentSiteOptOut else {
            os_log("Broker opts out in parent, skipping...", log: .dataBrokerProtection)
            return
        }

        let retriesCalculatorUseCase = OperationRetriesCalculatorUseCase()
        let stageDurationCalculator = DataBrokerProtectionStageDurationCalculator(dataBroker: brokerProfileQueryData.dataBroker.url, handler: pixelHandler)
        stageDurationCalculator.fireOptOutStart()
        os_log("Running opt-out operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

        defer {
            os_log("Finished opt-out operation: %{public}@", log: .dataBrokerProtection, String(describing: brokerProfileQueryData.dataBroker.name))

            try? database.updateLastRunDate(Date(), brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
            do {
                try updateOperationDataDates(
                    origin: .optOut,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: extractedProfileId,
                    schedulingConfig: brokerProfileQueryData.dataBroker.schedulingConfig,
                    database: database
                )
            } catch {
                handleOperationError(
                    origin: .optOut,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    extractedProfileId: extractedProfileId,
                    error: error,
                    database: database,
                    schedulingConfig: brokerProfileQueryData.dataBroker.schedulingConfig
                )
            }
            notificationCenter.post(name: DataBrokerProtectionNotifications.didFinishOptOut, object: brokerProfileQueryData.dataBroker.name)
        }

        do {
            try database.add(.init(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutStarted))

            try await runner.optOut(profileQuery: brokerProfileQueryData,
                                    extractedProfile: extractedProfile,
                                    stageCalculator: stageDurationCalculator,
                                    pixelHandler: pixelHandler,
                                    showWebView: showWebView,
                                    shouldRunNextStep: shouldRunNextStep)

            let tries = try retriesCalculatorUseCase.calculateForOptOut(database: database, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
            stageDurationCalculator.fireOptOutValidate()
            stageDurationCalculator.fireOptOutSubmitSuccess(tries: tries)

            let updater = OperationPreferredDateUpdaterUseCase(database: database)
            try updater.updateChildrenBrokerForParentBroker(brokerProfileQueryData.dataBroker,
                                                        profileQueryId: profileQueryId)

            try database.addAttempt(extractedProfileId: extractedProfileId,
                                attemptUUID: stageDurationCalculator.attemptId,
                                dataBroker: stageDurationCalculator.dataBroker,
                                lastStageDate: stageDurationCalculator.lastStateTime,
                                startTime: stageDurationCalculator.startTime)
            try database.add(.init(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested))
        } catch {
            let tries = try? retriesCalculatorUseCase.calculateForOptOut(database: database, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
            stageDurationCalculator.fireOptOutFailure(tries: tries ?? -1)
            handleOperationError(
                origin: .optOut,
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId,
                error: error,
                database: database,
                schedulingConfig: brokerProfileQueryData.dataBroker.schedulingConfig
            )
            throw error
        }
    }

    internal func updateOperationDataDates(
        origin: OperationPreferredDateUpdaterOrigin,
        brokerId: Int64,
        profileQueryId: Int64,
        extractedProfileId: Int64?,
        schedulingConfig: DataBrokerScheduleConfig,
        database: DataBrokerProtectionRepository) throws {

            let dateUpdater = OperationPreferredDateUpdaterUseCase(database: database)
            try dateUpdater.updateOperationDataDates(origin: origin,
                                                     brokerId: brokerId,
                                                     profileQueryId: profileQueryId,
                                                     extractedProfileId: extractedProfileId,
                                                     schedulingConfig: schedulingConfig)
        }

    private func handleOperationError(origin: OperationPreferredDateUpdaterOrigin,
                                      brokerId: Int64,
                                      profileQueryId: Int64,
                                      extractedProfileId: Int64?,
                                      error: Error,
                                      database: DataBrokerProtectionRepository,
                                      schedulingConfig: DataBrokerScheduleConfig) {
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

        try? database.add(event)

        do {
            try updateOperationDataDates(
                origin: origin,
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId,
                schedulingConfig: schedulingConfig,
                database: database
            )
        } catch {
            os_log("Can't update operation date after error")
        }

        os_log("Error on operation : %{public}@", log: .dataBrokerProtection, error.localizedDescription)
    }
}
