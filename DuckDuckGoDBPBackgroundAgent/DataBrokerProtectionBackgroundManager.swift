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

public final class DataBrokerProtectionBackgroundManager {

    static let shared = DataBrokerProtectionBackgroundManager()

    private let authenticationRepository: AuthenticationRepository = UserDefaultsAuthenticationData()
    private let authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let fakeBrokerFlag: FakeBrokerFlag = FakeBrokerUserDefaults()

    lazy var dataManager: DataBrokerProtectionDataManager = {
        DataBrokerProtectionDataManager(fakeBrokerFlag: fakeBrokerFlag)
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
        // Does the gpcEnabled flag actually matter?
        let prefs = ContentScopeProperties.init(gpcEnabled: false,
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

    public func startSchedulerIfPossible() {
        guard !redeemUseCase.shouldAskForInviteCode() else { return }

        // If there's no saved profileQueryData we don't need to start the scheduler
        // We should probably use a faster query for this, i.e: instead of returning data just check the count in the db
        if !dataManager.fetchBrokerProfileQueryData().isEmpty {
            scheduler.start()
        }
    }
}

public class DataBrokerProtectionErrorHandling: EventMapping<DataBrokerProtectionOperationError> {

    public init() {
        super.init { event, _, _, _ in
            //Pixel.fire(.debug(event: .dataBrokerProtectionError, error: event.error), withAdditionalParameters: event.params)
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionOperationError>.Mapping) {
        fatalError("Use init()")
    }
}
