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
import Freemium
import Subscription

// This is to avoid exposing all the dependancies outside of the DBP package
public class DataBrokerProtectionAgentManagerProvider {

    public static func agentManager(authenticationManager: DataBrokerProtectionAuthenticationManaging,
                                    accountManager: AccountManager) -> DataBrokerProtectionAgentManager {
        let pixelHandler = DataBrokerProtectionPixelsHandler()

        let executionConfig = DataBrokerExecutionConfig()
        let activityScheduler = DefaultDataBrokerProtectionBackgroundActivityScheduler(config: executionConfig)

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

        let emailService = EmailService(authenticationManager: authenticationManager)
        let captchaService = CaptchaService(authenticationManager: authenticationManager)
        let runnerProvider = DataBrokerJobRunnerProvider(privacyConfigManager: privacyConfigurationManager,
                                                         contentScopeProperties: contentScopeProperties,
                                                         emailService: emailService,
                                                         captchaService: captchaService)

        let freemiumPIRUserStateManager = DefaultFreemiumPIRUserStateManager(userDefaults: .dbp)

        let agentstopper = DefaultDataBrokerProtectionAgentStopper(dataManager: dataManager,
                                                                   entitlementMonitor: DataBrokerProtectionEntitlementMonitor(),
                                                                   authenticationManager: authenticationManager,
                                                                   pixelHandler: pixelHandler,
                                                                   freemiumPIRUserStateManager: freemiumPIRUserStateManager)

        let operationDependencies = DefaultDataBrokerOperationDependencies(
            database: dataManager.database,
            config: executionConfig,
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
            pixelHandler: pixelHandler,
            agentStopper: agentstopper,
            authenticationManager: authenticationManager,
            freemiumPIRUserStateManager: freemiumPIRUserStateManager)
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
    private let agentStopper: DataBrokerProtectionAgentStopper
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let freemiumPIRUserStateManager: FreemiumPIRUserStateManager

    // Used for debug functions only, so not injected
    private lazy var browserWindowManager = BrowserWindowManager()

    private var didStartActivityScheduler = false

    init(userNotificationService: DataBrokerProtectionUserNotificationService,
         activityScheduler: DataBrokerProtectionBackgroundActivityScheduler,
         ipcServer: DataBrokerProtectionIPCServer,
         queueManager: DataBrokerProtectionQueueManager,
         dataManager: DataBrokerProtectionDataManaging,
         operationDependencies: DataBrokerOperationDependencies,
         pixelHandler: EventMapping<DataBrokerProtectionPixels>,
         agentStopper: DataBrokerProtectionAgentStopper,
         authenticationManager: DataBrokerProtectionAuthenticationManaging,
         freemiumPIRUserStateManager: FreemiumPIRUserStateManager
    ) {
        self.userNotificationService = userNotificationService
        self.activityScheduler = activityScheduler
        self.ipcServer = ipcServer
        self.queueManager = queueManager
        self.dataManager = dataManager
        self.operationDependencies = operationDependencies
        self.pixelHandler = pixelHandler
        self.agentStopper = agentStopper
        self.authenticationManager = authenticationManager
        self.freemiumPIRUserStateManager = freemiumPIRUserStateManager

        self.activityScheduler.delegate = self
        self.ipcServer.serverDelegate = self
        self.ipcServer.activate()
    }

    public func agentFinishedLaunching() {

        Task { @MainActor in
            // The browser shouldn't start the agent if these prerequisites aren't met.
            // However, since the agent can auto-start after a reboot without the browser, we need to validate it again.
            // If the agent needs to be stopped, this function will stop it, so the subsequent calls after it will not be made.
            await agentStopper.validateRunPrerequisitesAndStopAgentIfNecessary()

            activityScheduler.startScheduler()
            didStartActivityScheduler = true
            fireMonitoringPixels()
            startFreemiumOrSubscriptionScheduledOperations(showWebView: false, operationDependencies: operationDependencies, completion: nil)

            /// Monitors entitlement changes every 60 minutes to optimize system performance and resource utilization by avoiding unnecessary operations when entitlement is invalid.
            /// While keeping the agent active with invalid entitlement has no significant risk, setting the monitoring interval at 60 minutes is a good balance to minimize backend checks.
            agentStopper.monitorEntitlementAndStopAgentIfEntitlementIsInvalidAndUserIsNotFreemium(interval: .minutes(60))
        }
    }
}

// MARK: - Regular monitoring pixels

extension DataBrokerProtectionAgentManager {
    func fireMonitoringPixels() {
        let database = operationDependencies.database

        let engagementPixels = DataBrokerProtectionEngagementPixels(database: database, handler: pixelHandler)
        let eventPixels = DataBrokerProtectionEventPixels(database: database, handler: pixelHandler)
        let statsPixels = DataBrokerProtectionStatsPixels(database: database, handler: pixelHandler)

        // This will fire the DAU/WAU/MAU pixels,
        engagementPixels.fireEngagementPixel()
        // This will try to fire the event weekly report pixels
        eventPixels.tryToFireWeeklyPixels()
        // This will try to fire the stats pixels
        statsPixels.tryToFireStatsPixels()
        // Fire custom stats pixels if needed
        statsPixels.fireCustomStatsPixelsIfNeeded()
    }
}

private extension DataBrokerProtectionAgentManager {

    /// Starts either Subscription (scan and opt-out) or Freemium (scan-only) scheduled operations
    /// - Parameters:
    ///   - showWebView: Whether to show the web view or not
    ///   - operationDependencies: Operation dependencies
    ///   - completion: Completion handler
    func startFreemiumOrSubscriptionScheduledOperations(showWebView: Bool,
                                                        operationDependencies: DataBrokerOperationDependencies,
                                                        completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?) {
        if authenticationManager.isUserAuthenticated {
            queueManager.startScheduledAllOperationsIfPermitted(showWebView: showWebView, operationDependencies: operationDependencies, completion: completion)
        } else {
            queueManager.startScheduledScanOperationsIfPermitted(showWebView: showWebView, operationDependencies: operationDependencies, completion: completion)
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionBackgroundActivitySchedulerDelegate {

    public func dataBrokerProtectionBackgroundActivitySchedulerDidTrigger(_ activityScheduler: DataBrokerProtection.DataBrokerProtectionBackgroundActivityScheduler, completion: (() -> Void)?) {
        fireMonitoringPixels()
        startFreemiumOrSubscriptionScheduledOperations(showWebView: false, operationDependencies: operationDependencies) { _ in
            completion?()
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentAppEvents {

    public func profileSaved() {
        let backgroundAgentInitialScanStartTime = Date()

        userNotificationService.requestNotificationPermission()
        fireMonitoringPixels()
        queueManager.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: operationDependencies) { [weak self] errors in
            guard let self = self else { return }

            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    switch oneTimeError {
                    case DataBrokerProtectionQueueError.interrupted:
                        self.pixelHandler.fire(.ipcServerImmediateScansInterrupted)
                        os_log("Interrupted during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateScanOperationsIfPermitted(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    default:
                        self.pixelHandler.fire(.ipcServerImmediateScansFinishedWithError(error: oneTimeError))
                        os_log("Error during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateScanOperationsIfPermitted, error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    }
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateScanOperationsIfPermitted, count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
            }

            if errors?.oneTimeError == nil {
                self.pixelHandler.fire(.ipcServerImmediateScansFinishedWithoutError)
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
        fireMonitoringPixels()
        startFreemiumOrSubscriptionScheduledOperations(showWebView: false,
                                                         operationDependencies:
                                                            operationDependencies) { [weak self] errors in
            guard let self = self else { return }

            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    switch oneTimeError {
                    case DataBrokerProtectionQueueError.interrupted:
                        self.pixelHandler.fire(.ipcServerAppLaunchedScheduledScansInterrupted)
                        os_log("Interrupted during DataBrokerProtectionAgentManager.appLaunched in queueManager.startScheduledAllOperationsIfPermitted(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    case DataBrokerProtectionQueueError.cannotInterrupt:
                        self.pixelHandler.fire(.ipcServerAppLaunchedScheduledScansBlocked)
                        os_log("Cannot interrupt during DataBrokerProtectionAgentManager.appLaunched in queueManager.startScheduledAllOperationsIfPermitted()")
                    default:
                        self.pixelHandler.fire(.ipcServerAppLaunchedScheduledScansFinishedWithError(error: oneTimeError))
                        os_log("Error during DataBrokerProtectionAgentManager.appLaunched in queueManager.startScheduledAllOperationsIfPermitted, error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    }
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateScanOperationsIfPermitted, count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
            }

            if errors?.oneTimeError == nil {
                self.pixelHandler.fire(.ipcServerAppLaunchedScheduledScansFinishedWithoutError)
            }
        }
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
        queueManager.startImmediateScanOperationsIfPermitted(showWebView: showWebView,
                                                         operationDependencies: operationDependencies,
                                                         completion: nil)
    }

    public func startScheduledOperations(showWebView: Bool) {
        startFreemiumOrSubscriptionScheduledOperations(showWebView: showWebView,
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
