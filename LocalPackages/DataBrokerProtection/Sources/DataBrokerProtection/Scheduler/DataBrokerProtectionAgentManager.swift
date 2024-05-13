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

public final class DataBrokerProtectionAgentManager {

    public static let shared: DataBrokerProtectionAgentManager = {
        return DataBrokerProtectionAgentManager(activityScheduler: DataBrokerProtectionBackgroundActivityScheduler())
    }()

    private let pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()

    private let authenticationRepository: AuthenticationRepository = KeychainAuthenticationData()
    private let authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()
    private lazy var userNotificationService = DefaultDataBrokerProtectionUserNotificationService(pixelHandler: pixelHandler)
    private let activityScheduler: DataBrokerProtectionBackgroundActivityScheduler

    private lazy var redeemUseCase: DataBrokerProtectionRedeemUseCase = {
        return RedeemUseCase(authenticationService: authenticationService,
                             authenticationRepository: authenticationRepository)
    }()
    private let fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker()
    private lazy var browserWindowManager = BrowserWindowManager()
    private var didStartActivityScheduler = false

    private lazy var privacyConfigurationManager = PrivacyConfigurationManagingMock() // Forgive me, for I have sinned
    private lazy var contentScopeProperties: ContentScopeProperties = {
        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false)

        let sessionKey = UUID().uuidString
        return ContentScopeProperties(gpcEnabled: false,
                                      sessionKey: sessionKey,
                                      featureToggles: features)
    }()

    private lazy var ipcServer: DataBrokerProtectionIPCServer = {
        let server = DataBrokerProtectionIPCServer(machServiceName: Bundle.main.bundleIdentifier!)
        server.serverDelegate = self
        return server
    }()

    lazy var dataManager: DataBrokerProtectionDataManager = {
        DataBrokerProtectionDataManager(pixelHandler: pixelHandler, fakeBrokerFlag: fakeBrokerFlag)
    }()

    private lazy var queueManager: DataBrokerProtectionQueueManager = {
           let operationQueue = OperationQueue()
           let operationsBuilder = DefaultDataBrokerOperationsCreator()
           let mismatchCalculator = DefaultMismatchCalculator(database: dataManager.database,
                                                              pixelHandler: pixelHandler)

           var brokerUpdater: DataBrokerProtectionBrokerUpdater?
           if let vault = try? DataBrokerProtectionSecureVaultFactory.makeVault(reporter: nil) {
               brokerUpdater = DefaultDataBrokerProtectionBrokerUpdater(vault: vault, pixelHandler: pixelHandler)
           }

           return DefaultDataBrokerProtectionQueueManager(operationQueue: operationQueue,
                                                          operationsCreator: operationsBuilder,
                                                          mismatchCalculator: mismatchCalculator,
                                                          brokerUpdater: brokerUpdater,
                                                          pixelHandler: pixelHandler)
       }()

    private lazy var operationDependencies: DataBrokerOperationDependencies = {
        let emailService = EmailService(redeemUseCase: redeemUseCase)
        let captchaService = CaptchaService(redeemUseCase: redeemUseCase)
        let runnerProvider = DataBrokerJobRunnerProvider(privacyConfigManager: privacyConfigurationManager,
                                                         contentScopeProperties: contentScopeProperties,
                                                         emailService: emailService,
                                                         captchaService: captchaService)

        return DefaultDataBrokerOperationDependencies(database: dataManager.database,
                                                      config: DataBrokerProtectionProcessorConfiguration(),
                                                      runnerProvider: runnerProvider,
                                                      notificationCenter: NotificationCenter.default,
                                                      pixelHandler: pixelHandler, userNotificationService: userNotificationService)
    }()

    private init(activityScheduler: DataBrokerProtectionBackgroundActivityScheduler) {
        self.activityScheduler = activityScheduler
        activityScheduler.delegate = self
        ipcServer.activate()
    }

    public func agentFinishedLaunching() {
        pixelHandler.fire(.backgroundAgentRunOperationsAndStartSchedulerIfPossible)

        do {
            // If there's no saved profile we don't need to start the scheduler
            // Theoretically this should never happen, if there's no data, the agent shouldn't be running
            guard (try dataManager.fetchProfile()) != nil else {
                pixelHandler.fire(.backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile)
                return
            }
        } catch {
            pixelHandler.fire(.generalError(error: error,
                                            functionOccurredIn: "DataBrokerProtectionBackgroundManager.runOperationsAndStartSchedulerIfPossible"))
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
        let backgroundAgentManualScanStartTime = Date()

        userNotificationService.requestNotificationPermission()
        queueManager.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: operationDependencies) { [weak self] errors in
            guard let self = self else { return }

            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    switch oneTimeError {
                    case DataBrokerProtectionAppToAgentInterfaceError.operationsInterrupted:
                        os_log("Interrupted during DefaultDataBrokerProtectionScheduler.startManualScan in dataBrokerProcessor.runAllScanOperations(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    default:
                        os_log("Error during DefaultDataBrokerProtectionScheduler.startManualScan in dataBrokerProcessor.runAllScanOperations(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                        self.pixelHandler.fire(.generalError(error: oneTimeError, functionOccurredIn: "DefaultDataBrokerProtectionScheduler.startManualScan"))
                    }
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during DefaultDataBrokerProtectionScheduler.startManualScan in dataBrokerProcessor.runAllScanOperations(), count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
            }

            if errors?.oneTimeError == nil {
                self.userNotificationService.sendFirstScanCompletedNotification()
            }

            if let hasMatches = try? self.dataManager.hasMatches(),
                hasMatches {
                self.userNotificationService.scheduleCheckInNotificationIfPossible()
            }

            fireManualScanCompletionPixel(startTime: backgroundAgentManualScanStartTime)
        }
    }

    public func appLaunched() {
        queueManager.startScheduledOperationsIfPermitted(showWebView: false,
                                                         operationDependencies:
                                                            operationDependencies, completion: nil)
    }

    private func fireManualScanCompletionPixel(startTime: Date) {
        do {
            let profileQueries = try dataManager.profileQueriesCount()
            let durationSinceStart = Date().timeIntervalSince(startTime) * 1000
            self.pixelHandler.fire(.initialScanTotalDuration(duration: durationSinceStart.rounded(.towardZero),
                                                             profileQueries: profileQueries))
        } catch {
            os_log("Manual Scan Error when trying to fetch the profile to get the profile queries", log: .dataBrokerProtection)
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentDebugCommands {
    public func openBrowser(domain: String) {
        Task { @MainActor in
            browserWindowManager.show(domain: domain)
        }
    }

    public func startManualScan(showWebView: Bool) {
        queueManager.startImmediateOperationsIfPermitted(showWebView: showWebView, 
                                                         operationDependencies: operationDependencies,
                                                         completion: nil)
    }

    public func runQueuedOperations(showWebView: Bool) {
        // TODO
        //scheduler.runQueuedOperations(showWebView: showWebView)
    }

    public func runAllOptOuts(showWebView: Bool) {
        // TODO
//        scheduler.runAllOptOuts(showWebView: showWebView) { _ in
//
//        }
    }

    public func getDebugMetadata() async -> DataBrokerProtection.DBPBackgroundAgentMetadata? {

        if let backgroundAgentVersion = Bundle.main.releaseVersionNumber,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {

            return DBPBackgroundAgentMetadata(backgroundAgentVersion: backgroundAgentVersion + " (build: \(buildNumber))",
                                              isAgentRunning: true,
                                              agentSchedulerState: "TODO",
                                              lastSchedulerSessionStartTimestamp: activityScheduler.lastTriggerTimestamp?.timeIntervalSince1970)
        } else {
            return DBPBackgroundAgentMetadata(backgroundAgentVersion: "ERROR: Error fetching background agent version",
                                              isAgentRunning: true,
                                              agentSchedulerState: "TODO",
                                              lastSchedulerSessionStartTimestamp: activityScheduler.lastTriggerTimestamp?.timeIntervalSince1970)
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAppToAgentInterface {

}
