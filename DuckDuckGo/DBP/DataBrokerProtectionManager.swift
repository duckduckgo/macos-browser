//
//  DataBrokerProtectionManager.swift
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
import BrowserServicesKit
import DataBrokerProtection

public final class DataBrokerProtectionManager {

    static let shared = DataBrokerProtectionManager()

    private let authenticationRepository: AuthenticationRepository = UserDefaultsAuthenticationData()
    private let authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let fakeBrokerFlag: FakeBrokerFlag = FakeBrokerUserDefaults()

    lazy var dataManager: DataBrokerProtectionDataManager = {
        DataBrokerProtectionDataManager(fakeBrokerFlag: fakeBrokerFlag)
    }()

    lazy var scheduler: DataBrokerProtectionScheduler = {
        let privacyConfigurationManager = PrivacyFeatures.contentBlocking.privacyConfigurationManager
        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false)

        let privacySettings = PrivacySecurityPreferences.shared
        let sessionKey = UUID().uuidString
        let prefs = ContentScopeProperties.init(gpcEnabled: privacySettings.gpcEnabled,
                                                sessionKey: sessionKey,
                                                featureToggles: features)

        return DefaultDataBrokerProtectionScheduler(privacyConfigManager: privacyConfigurationManager,
                                                  contentScopeProperties: prefs,
                                                  dataManager: dataManager,
                                                  notificationCenter: NotificationCenter.default,
                                                  errorHandler: DataBrokerProtectionErrorHandling(),
                                                  redeemUseCase: redeemUseCase)
    }()

    private init() {
        self.redeemUseCase = RedeemUseCase(authenticationService: authenticationService,
                                           authenticationRepository: authenticationRepository)

    }

    public func shouldAskForInviteCode() -> Bool {
        redeemUseCase.shouldAskForInviteCode()
    }

    public func runOperationsAndStartSchedulerIfPossible() {
        guard !redeemUseCase.shouldAskForInviteCode() else { return }

        /*
         // TODO make the background agent do it, for now, do nothing
        // If there's no saved profile we don't need to start the scheduler
        if dataManager.fetchProfile() != nil {
            scheduler.runQueuedOperations(showWebView: false) { [weak self] in
                self?.scheduler.startScheduler()
            }

            //scheduler.scanAllBrokers()
        }
         */
    }
}
