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
import os.log

enum OperationsError: Error {
    case idsMissingForBrokerOrProfileQuery
}

protocol OperationsManager {

    // We want to refactor this to return a NSOperation in the future
    // so we have more control of stopping/starting the queue
    // for the time being, shouldRunNextStep: @escaping () -> Bool is being used
    func runOperation(operationData: BrokerJobData,
                      brokerProfileQueryData: BrokerProfileQueryData,
                      database: DataBrokerProtectionRepository,
                      notificationCenter: NotificationCenter,
                      runner: WebJobRunner,
                      pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                      showWebView: Bool,
                      isImmediateOperation: Bool,
                      userNotificationService: DataBrokerProtectionUserNotificationService,
                      shouldRunNextStep: @escaping () -> Bool) async throws
}

extension OperationsManager {
    func runOperation(operationData: BrokerJobData,
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
                               isImmediateOperation: isManual,
                               userNotificationService: userNotificationService,
                               shouldRunNextStep: shouldRunNextStep)
    }
}

struct DataBrokerProfileQueryOperationManager: OperationsManager {

    internal func runOperation(operationData: BrokerJobData,
                               brokerProfileQueryData: BrokerProfileQueryData,
                               database: DataBrokerProtectionRepository,
                               notificationCenter: NotificationCenter = NotificationCenter.default,
                               runner: WebJobRunner,
                               pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                               showWebView: Bool = false,
                               isImmediateOperation: Bool = false,
                               userNotificationService: DataBrokerProtectionUserNotificationService,
                               shouldRunNextStep: @escaping () -> Bool) async throws {

        if operationData as? ScanJobData != nil {
            try await runScanOperation(on: runner,
                                       brokerProfileQueryData: brokerProfileQueryData,
                                       database: database,
                                       notificationCenter: notificationCenter,
                                       pixelHandler: pixelHandler,
                                       showWebView: showWebView,
                                       isManual: isImmediateOperation,
                                       userNotificationService: userNotificationService,
                                       shouldRunNextStep: shouldRunNextStep)
        } else if let optOutJobData = operationData as? OptOutJobData {
            try await runOptOutOperation(for: optOutJobData.extractedProfile,
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

    // swiftlint:disable cyclomatic_complexity
    internal func runScanOperation(on runner: WebJobRunner,
                                   brokerProfileQueryData: BrokerProfileQueryData,
                                   database: DataBrokerProtectionRepository,
                                   notificationCenter: NotificationCenter,
                                   pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                                   showWebView: Bool = false,
                                   isManual: Bool = false,
                                   userNotificationService: DataBrokerProtectionUserNotificationService,
                                   shouldRunNextStep: @escaping () -> Bool) async throws {
        Logger.dataBrokerProtection.log("Running scan operation: \(brokerProfileQueryData.dataBroker.name, privacy: .public)")

        guard let brokerId = brokerProfileQueryData.dataBroker.id, let profileQueryId = brokerProfileQueryData.profileQuery.id else {
            // Maybe send pixel?
            throw OperationsError.idsMissingForBrokerOrProfileQuery
        }

        defer {
            try? database.updateLastRunDate(Date(), brokerId: brokerId, profileQueryId: profileQueryId)
            Logger.dataBrokerProtection.log("Finished scan operation: \(brokerProfileQueryData.dataBroker.name, privacy: .public)")
            notificationCenter.post(name: DataBrokerProtectionNotifications.didFinishScan, object: brokerProfileQueryData.dataBroker.name)
        }

        let eventPixels = DataBrokerProtectionEventPixels(database: database, handler: pixelHandler)
        let stageCalculator = DataBrokerProtectionStageDurationCalculator(dataBroker: brokerProfileQueryData.dataBroker.name,
                                                                          dataBrokerVersion: brokerProfileQueryData.dataBroker.version,
                                                                          handler: pixelHandler,
                                                                          isImmediateOperation: isManual)

        do {
            let event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .scanStarted)
            try database.add(event)

            let extractedProfiles = try await runner.scan(brokerProfileQueryData, stageCalculator: stageCalculator, pixelHandler: pixelHandler, showWebView: showWebView, shouldRunNextStep: shouldRunNextStep)
            Logger.dataBrokerProtection.log("Extracted profiles: \(extractedProfiles)")

            if !extractedProfiles.isEmpty {
                stageCalculator.fireScanSuccess(matchesFound: extractedProfiles.count)
                let event = HistoryEvent(brokerId: brokerId, profileQueryId: profileQueryId, type: .matchesFound(count: extractedProfiles.count))
                try database.add(event)
                let extractedProfilesForBroker = try database.fetchExtractedProfiles(for: brokerId)

                for extractedProfile in extractedProfiles {

                    // We check if the profile exists in the database.
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

                        Logger.dataBrokerProtection.log("Extracted profile already exists in database: \(id.description)")
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
                        let optOutJobData = OptOutJobData(brokerId: brokerId,
                                                          profileQueryId: profileQueryId,
                                                          createdDate: Date(),
                                                          preferredRunDate: preferredRunOperation,
                                                          historyEvents: [HistoryEvent](),
                                                          attemptCount: 0,
                                                          submittedSuccessfullyDate: nil,
                                                          extractedProfile: extractedProfile,
                                                          sevenDaysConfirmationPixelFired: false,
                                                          fourteenDaysConfirmationPixelFired: false,
                                                          twentyOneDaysConfirmationPixelFired: false)

                        try database.saveOptOutJob(optOut: optOutJobData, extractedProfile: extractedProfile)

                        Logger.dataBrokerProtection.log("Creating new opt-out operation data for: \(String(describing: extractedProfile.name))")
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

                        Logger.dataBrokerProtection.log("Profile removed from optOutsData: \(String(describing: removedProfile))")

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
    // swiftlint:enable cyclomatic_complexity

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
            Logger.dataBrokerProtection.log("Profile already removed, skipping...")
            return
        }

        guard !brokerProfileQueryData.dataBroker.performsOptOutWithinParent() else {
            Logger.dataBrokerProtection.log("Broker opts out in parent, skipping...")
            return
        }

        let retriesCalculatorUseCase = OperationRetriesCalculatorUseCase()
        let stageDurationCalculator = DataBrokerProtectionStageDurationCalculator(dataBroker: brokerProfileQueryData.dataBroker.url,
                                                                                  dataBrokerVersion: brokerProfileQueryData.dataBroker.version,
                                                                                  handler: pixelHandler)
        stageDurationCalculator.fireOptOutStart()
        Logger.dataBrokerProtection.log("Running opt-out operation: \(brokerProfileQueryData.dataBroker.name, privacy: .public)")

        defer {
            Logger.dataBrokerProtection.log("Finished opt-out operation: \(brokerProfileQueryData.dataBroker.name, privacy: .public)")

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
            try incrementAttemptCountIfNeeded(
                database: database,
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId
            )
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

    private func incrementAttemptCountIfNeeded(database: DataBrokerProtectionRepository,
                                               brokerId: Int64,
                                               profileQueryId: Int64,
                                               extractedProfileId: Int64) throws {
        guard let events = try? database.fetchOptOutHistoryEvents(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId),
              events.max(by: { $0.date < $1.date })?.type == .optOutRequested else {
            return
        }

        try database.incrementAttemptCount(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
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
            Logger.dataBrokerProtection.log("Can't update operation date after error")
        }

        Logger.dataBrokerProtection.error("Error on operation : \(error.localizedDescription, privacy: .public)")
    }
}
