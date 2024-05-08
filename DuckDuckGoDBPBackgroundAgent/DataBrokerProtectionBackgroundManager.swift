//
//  DataBrokerProtectionBackgroundManager.swift
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
import Subscription

public final class DataBrokerProtectionBackgroundManager {

    static let shared = DataBrokerProtectionBackgroundManager()

    private let pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()

    private let authenticationRepository: AuthenticationRepository = KeychainAuthenticationData()
    private let authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker()

    private let subscriptionHandler: DataBrokerProtectionSubscriptionHandler

    private lazy var ipcServiceManager = IPCServiceManager(scheduler: scheduler, pixelHandler: pixelHandler)

    lazy var dataManager: DataBrokerProtectionDataManager = {
        DataBrokerProtectionDataManager(pixelHandler: pixelHandler, fakeBrokerFlag: fakeBrokerFlag)
    }()

    lazy var scheduler: DataBrokerProtectionScheduler = {
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
        self.subscriptionHandler =  DataBrokerProtectionSubscriptionHandler(accountManager: AccountManager(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs)))
        self.redeemUseCase = subscriptionHandler
        _ = ipcServiceManager
    }

    public func runOperationsAndStartSchedulerIfPossible() {
        testSubscription()

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

        scheduler.runQueuedOperations(showWebView: false) { [weak self] errors in
            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    os_log("Error during BackgroundManager runOperationsAndStartSchedulerIfPossible in scheduler.runQueuedOperations(), error: %{public}@",
                           log: .dataBrokerProtection,
                           oneTimeError.localizedDescription)
                    self?.pixelHandler.fire(.generalError(error: oneTimeError,
                                                          functionOccurredIn: "DataBrokerProtectionBackgroundManager.runOperationsAndStartSchedulerIfPossible"))
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during  BackgroundManager runOperationsAndStartSchedulerIfPossible in scheduler.runQueuedOperations(), count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
                return
            }

            self?.pixelHandler.fire(.backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackStartScheduler)
            self?.scheduler.startScheduler()
        }
    }

    private func testSubscription() {
        print("USER AUTH \(subscriptionHandler.isUserAuthenticated ? "YES" : "NO")")

        if let token = subscriptionHandler.accessToken {
            print("TOKEN \(token)")
        }
        Task {
            switch await subscriptionHandler.hasValidEntitlement() {
            case let .success(result):
                print("ENTITLEMENT \(result ? "YES" : "NO")")
            case .failure(let error):
                print("ENTITLEMENT FAILURE \(error)")
            }
        }
    }
}

extension AccountManager: DataBrokerProtectionAccountManaging {
    public func hasEntitlement(for cachePolicy: CachePolicy) async -> Result<Bool, any Error> {
        await hasEntitlement(for: .dataBrokerProtection, cachePolicy: cachePolicy)
    }
}

extension DataBrokerProtectionSubscriptionHandler: DataBrokerProtectionRedeemUseCase {
    public func shouldAskForInviteCode() -> Bool {
        false
    }

    public func redeem(inviteCode: String) async throws {
        print("Potato")
    }

    public func getAuthHeader() -> String? {

        guard let token = accessToken else {
            return nil
        }
        return "bearer \(token)"
    }
}
