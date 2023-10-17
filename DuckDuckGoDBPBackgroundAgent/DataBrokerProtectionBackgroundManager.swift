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
import Common
import BrowserServicesKit
import DataBrokerProtection
import PixelKit

public final class DataBrokerProtectionBackgroundManager {

    static let shared = DataBrokerProtectionBackgroundManager()

    private let authenticationRepository: AuthenticationRepository = UserDefaultsAuthenticationData()
    private let authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker()

    private lazy var ipcServiceManager = IPCServiceManager(scheduler: scheduler)

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
        let prefs = ContentScopeProperties.init(gpcEnabled: false,
                                                sessionKey: sessionKey,
                                                featureToggles: features)

        return DefaultDataBrokerProtectionScheduler(privacyConfigManager: privacyConfigurationManager,
                                                  contentScopeProperties: prefs,
                                                  dataManager: dataManager,
                                                  notificationCenter: NotificationCenter.default,
                                                  pixelHandler: DataBrokerProtectionPixelsHandler(),
                                                  redeemUseCase: redeemUseCase)
    }()

    private init() {
        self.redeemUseCase = RedeemUseCase(authenticationService: authenticationService,
                                           authenticationRepository: authenticationRepository)
        _ = ipcServiceManager
    }

    public func runOperationsAndStartSchedulerIfPossible() {

        // If there's no saved profile we don't need to start the scheduler
        if dataManager.fetchProfile() != nil {
            scheduler.runQueuedOperations(showWebView: false) { [weak self] error in
                guard error == nil else {
                    return
                }

                self?.scheduler.startScheduler()
            }
        }
    }
}
/*
public class DataBrokerProtectionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {

    public init() {
        super.init { _, _, _, _ in

        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}*/
