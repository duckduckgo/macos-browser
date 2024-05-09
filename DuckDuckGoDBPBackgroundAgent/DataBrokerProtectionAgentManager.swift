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
import DataBrokerProtection
import PixelKit

public final class DataBrokerProtectionAgentManager {

    static let shared = DataBrokerProtectionAgentManager()

    private let pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()

    private let authenticationRepository: AuthenticationRepository = KeychainAuthenticationData()
    private let authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker()
    private lazy var browserWindowManager = BrowserWindowManager()

    private lazy var ipcServer: DataBrokerProtectionIPCServer = {
        let server = DataBrokerProtectionIPCServer(machServiceName: Bundle.main.bundleIdentifier!)
        server.serverDelegate = self
        return server
    }()

    lazy var dataManager: DataBrokerProtectionDataManager = {
        DataBrokerProtectionDataManager(pixelHandler: pixelHandler, fakeBrokerFlag: fakeBrokerFlag)
    }()

    lazy var scheduler: DefaultDataBrokerProtectionScheduler = {
        let privacyConfigurationManager = PrivacyConfigurationManagingMock() // Forgive me, for I have sinned
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
        let prefs = ContentScopeProperties(gpcEnabled: false,
                                                sessionKey: sessionKey,
                                                featureToggles: features)

        let pixelHandler = DataBrokerProtectionPixelsHandler()

        let userNotificationService = DefaultDataBrokerProtectionUserNotificationService(pixelHandler: pixelHandler)

        return DefaultDataBrokerProtectionScheduler(privacyConfigManager: privacyConfigurationManager,
                                                    contentScopeProperties: prefs,
                                                    dataManager: dataManager,
                                                    notificationCenter: NotificationCenter.default,
                                                    pixelHandler: pixelHandler,
                                                    redeemUseCase: redeemUseCase,
                                                    userNotificationService: userNotificationService)
    }()

    private init() {
        self.redeemUseCase = RedeemUseCase(authenticationService: authenticationService,
                                           authenticationRepository: authenticationRepository)
        ipcServer.activate()
    }

    public func agentFinishedLaunching() {
        pixelHandler.fire(.backgroundAgentRunOperationsAndStartSchedulerIfPossible)

        do {
            // If there's no saved profile we don't need to start the scheduler
            guard (try dataManager.fetchProfile()) != nil else {
                pixelHandler.fire(.backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile)
                return
            }
        } catch {
            pixelHandler.fire(.generalError(error: error,
                                            functionOccurredIn: "DataBrokerProtectionBackgroundManager.runOperationsAndStartSchedulerIfPossible"))
            return
        }

        scheduler.runQueuedOperations(showWebView: false) { [weak self] _ in
            self?.pixelHandler.fire(.backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackStartScheduler)
            self?.scheduler.startScheduler()
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentAppEvents {

    public func profileSaved() {
        scheduler.startManualScan(startTime: Date()) { _ in

        }
    }

    public func dataDeleted() {
        scheduler.stopScheduler()
    }

    public func appLaunched() {
        scheduler.runQueuedOperations()
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentDebugCommands {
    public func openBrowser(domain: String) {
        Task { @MainActor in
            browserWindowManager.show(domain: domain)
        }
    }

    public func startManualScan(showWebView: Bool) {
        scheduler.startManualScan(startTime: Date()) { _ in

        }
    }

    public func runQueuedOperations(showWebView: Bool) {
        scheduler.runQueuedOperations(showWebView: showWebView)
    }

    public func runAllOptOuts(showWebView: Bool) {
        scheduler.optOutAllBrokers(showWebView: showWebView) { _ in

        }
    }

    public func getDebugMetadata() async -> DataBrokerProtection.DBPBackgroundAgentMetadata? {

        if let backgroundAgentVersion = Bundle.main.releaseVersionNumber,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {

            return DBPBackgroundAgentMetadata(backgroundAgentVersion: backgroundAgentVersion + " (build: \(buildNumber))",
                                              isAgentRunning: scheduler.status == .running,
                                              agentSchedulerState: scheduler.status.toString,
                                              lastSchedulerSessionStartTimestamp: scheduler.lastSchedulerSessionStartTimestamp?.timeIntervalSince1970)
        } else {
            return DBPBackgroundAgentMetadata(backgroundAgentVersion: "ERROR: Error fetching background agent version",
                                              isAgentRunning: scheduler.status == .running,
                                              agentSchedulerState: scheduler.status.toString,
                                              lastSchedulerSessionStartTimestamp: scheduler.lastSchedulerSessionStartTimestamp?.timeIntervalSince1970)
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentInterface {

}
