//
//  DataBrokerProtectionAgentManager.swift
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
import BrowserServicesKit
import PixelKit

// This is to avoid exposing all the dependancies outside of the DBP package
public class DataBrokerProtectionAgentManagerProvider {
    // swiftlint:disable:next function_body_length
    public static func agentManager() -> DataBrokerProtectionAgentManager {
        let pixelHandler = DataBrokerProtectionPixelsHandler()
        let activityScheduler = DefaultDataBrokerProtectionBackgroundActivityScheduler()
        let notificationService = DefaultDataBrokerProtectionUserNotificationService(pixelHandler: pixelHandler)
        let privacyConfigurationManager = PrivacyConfigurationManagingMock() // Forgive me, for I have sinned
        let ipcServer = DefaultDataBrokerProtectionIPCServer(machServiceName: Bundle.main.bundleIdentifier!)

        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false)
        let contentScopeProperties = ContentScopeProperties(gpcEnabled: false,
                                                            sessionKey: UUID().uuidString,
                                                            featureToggles: features)

        let fakeBroker = DataBrokerDebugFlagFakeBroker()
        let dataManager = DataBrokerProtectionDataManager(pixelHandler: pixelHandler, fakeBrokerFlag: fakeBroker)

        let operationQueue = OperationQueue()
        let operationsBuilder = DefaultDataBrokerOperationsCreator()
        let mismatchCalculator = DefaultMismatchCalculator(database: dataManager.database,
                                                           pixelHandler: pixelHandler)

        var brokerUpdater: DataBrokerProtectionBrokerUpdater?
        if let vault = try? DataBrokerProtectionSecureVaultFactory.makeVault(reporter: nil) {
            brokerUpdater = DefaultDataBrokerProtectionBrokerUpdater(vault: vault, pixelHandler: pixelHandler)
        }
        let queueManager =  DefaultDataBrokerProtectionQueueManager(operationQueue: operationQueue,
                                                       operationsCreator: operationsBuilder,
                                                       mismatchCalculator: mismatchCalculator,
                                                       brokerUpdater: brokerUpdater,
                                                       pixelHandler: pixelHandler)

        let redeemUseCase = RedeemUseCase(authenticationService: AuthenticationService(),
                                          authenticationRepository: KeychainAuthenticationData())
        let emailService = EmailService(redeemUseCase: redeemUseCase)
        let captchaService = CaptchaService(redeemUseCase: redeemUseCase)
        let runnerProvider = DataBrokerJobRunnerProvider(privacyConfigManager: privacyConfigurationManager,
                                                         contentScopeProperties: contentScopeProperties,
                                                         emailService: emailService,
                                                         captchaService: captchaService)
         let operationDependencies = DefaultDataBrokerOperationDependencies(
            database: dataManager.database,
            config: DataBrokerProtectionProcessorConfiguration(),
            runnerProvider: runnerProvider,
            notificationCenter: NotificationCenter.default,
            pixelHandler: pixelHandler,
            userNotificationService: notificationService)

        return DataBrokerProtectionAgentManager(
            userNotificationService: notificationService,
            activityScheduler: activityScheduler,
            ipcServer: ipcServer,
            queueManager: queueManager,
            dataManager: dataManager,
            operationDependencies: operationDependencies,
            pixelHandler: pixelHandler)
    }
}

public final class DataBrokerProtectionAgentManager {

    private let userNotificationService: DataBrokerProtectionUserNotificationService
    private var activityScheduler: DataBrokerProtectionBackgroundActivityScheduler
    private var ipcServer: DataBrokerProtectionIPCServer
    private let queueManager: DataBrokerProtectionQueueManager
    private let dataManager: DataBrokerProtectionDataManaging
    private let operationDependencies: DataBrokerOperationDependencies
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>

    // Used for debug functions only, so not injected
    private lazy var browserWindowManager = BrowserWindowManager()

    private var didStartActivityScheduler = false

    init(userNotificationService: DataBrokerProtectionUserNotificationService,
         activityScheduler: DataBrokerProtectionBackgroundActivityScheduler,
         ipcServer: DataBrokerProtectionIPCServer,
         queueManager: DataBrokerProtectionQueueManager,
         dataManager: DataBrokerProtectionDataManaging,
         operationDependencies: DataBrokerOperationDependencies,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>) {
        self.userNotificationService = userNotificationService
        self.activityScheduler = activityScheduler
        self.ipcServer = ipcServer
        self.queueManager = queueManager
        self.dataManager = dataManager
        self.operationDependencies = operationDependencies
        self.pixelHandler = pixelHandler

        self.activityScheduler.delegate = self
        self.ipcServer.serverDelegate = self
        self.ipcServer.activate()
    }

    public func agentFinishedLaunching() {
        pixelHandler.fire(.backgroundAgentRunOperationsAndStartSchedulerIfPossible)

        do {
            // If there's no saved profile we don't need to start the scheduler
            // Theoretically this should never happen, if there's no data, the agent shouldn't be running
            guard (try dataManager.fetchProfile()) != nil else {
                return
            }
        } catch {
            os_log("Error during AgentManager.agentFinishedLaunching when trying to fetchProfile, error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
            return
        }

        activityScheduler.startScheduler()
        didStartActivityScheduler = true
        queueManager.startScheduledOperationsIfPermitted(showWebView: false, operationDependencies: operationDependencies, completion: nil)
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionBackgroundActivitySchedulerDelegate {

    public func dataBrokerProtectionBackgroundActivitySchedulerDidTrigger(_ activityScheduler: DataBrokerProtection.DataBrokerProtectionBackgroundActivityScheduler) {
        queueManager.startScheduledOperationsIfPermitted(showWebView: false, operationDependencies: operationDependencies, completion: nil)
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentAppEvents {

    public func profileSaved() {
        let startTime = Date()
        pixelHandler.fire(.initialScanPreStartDuration(duration: (Date().timeIntervalSince(startTime) * 1000).rounded(.towardZero)))
        let backgroundAgentInitialScanStartTime = Date()

        userNotificationService.requestNotificationPermission()
        queueManager.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: operationDependencies) { [weak self] errors in
            guard let self = self else { return }

            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    switch oneTimeError {
                    case DataBrokerProtectionAppToAgentInterfaceError.operationsInterrupted:
                        os_log("Interrupted during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateOperationsIfPermitted(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    default:
                        os_log("Error during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateOperationsIfPermitted, error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                        self.pixelHandler.fire(.generalError(error: oneTimeError, functionOccurredIn: "DataBrokerProtectionAgentManager.profileSaved"))
                    }
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateOperationsIfPermitted, count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
            }

            if errors?.oneTimeError == nil {
                self.userNotificationService.sendFirstScanCompletedNotification()
            }

            if let hasMatches = try? self.dataManager.hasMatches(),
                hasMatches {
                self.userNotificationService.scheduleCheckInNotificationIfPossible()
            }

            fireImmediateScansCompletionPixel(startTime: backgroundAgentInitialScanStartTime)
        }
    }

    public func appLaunched() {
        queueManager.startScheduledOperationsIfPermitted(showWebView: false,
                                                         operationDependencies:
                                                            operationDependencies, completion: nil)
    }

    private func fireImmediateScansCompletionPixel(startTime: Date) {
        do {
            let profileQueries = try dataManager.profileQueriesCount()
            let durationSinceStart = Date().timeIntervalSince(startTime) * 1000
            self.pixelHandler.fire(.initialScanTotalDuration(duration: durationSinceStart.rounded(.towardZero),
                                                             profileQueries: profileQueries))
        } catch {
            os_log("Initial Scans Error when trying to fetch the profile to get the profile queries", log: .dataBrokerProtection)
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentDebugCommands {
    public func openBrowser(domain: String) {
        Task { @MainActor in
            browserWindowManager.show(domain: domain)
        }
    }

    public func startImmediateOperations(showWebView: Bool) {
        queueManager.startImmediateOperationsIfPermitted(showWebView: showWebView,
                                                         operationDependencies: operationDependencies,
                                                         completion: nil)
    }

    public func startScheduledOperations(showWebView: Bool) {
        queueManager.startScheduledOperationsIfPermitted(showWebView: showWebView,
                                                         operationDependencies: operationDependencies,
                                                         completion: nil)
    }

    public func runAllOptOuts(showWebView: Bool) {
        queueManager.execute(.startOptOutOperations(showWebView: showWebView, 
                                                    operationDependencies: operationDependencies,
                                                    completion: nil))
    }

    public func getDebugMetadata() async -> DataBrokerProtection.DBPBackgroundAgentMetadata? {

        if let backgroundAgentVersion = Bundle.main.releaseVersionNumber,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {

            return DBPBackgroundAgentMetadata(backgroundAgentVersion: backgroundAgentVersion + " (build: \(buildNumber))",
                                              isAgentRunning: true,
                                              agentSchedulerState: queueManager.debugRunningStatusString,
                                              lastSchedulerSessionStartTimestamp: activityScheduler.lastTriggerTimestamp?.timeIntervalSince1970)
        } else {
            return DBPBackgroundAgentMetadata(backgroundAgentVersion: "ERROR: Error fetching background agent version",
                                              isAgentRunning: true,
                                              agentSchedulerState: queueManager.debugRunningStatusString,
                                              lastSchedulerSessionStartTimestamp: activityScheduler.lastTriggerTimestamp?.timeIntervalSince1970)
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAppToAgentInterface {

}
