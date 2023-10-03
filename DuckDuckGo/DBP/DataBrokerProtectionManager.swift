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
import LoginItems
import Common

public final class DataBrokerProtectionManager {

    static let shared = DataBrokerProtectionManager()

    private let authenticationRepository: AuthenticationRepository = UserDefaultsAuthenticationData()
    private let authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker()
    private let ipcConnection = DBPIPCConnection(log: .dbpBackgroundAgent, memoryManagementLog: .dbpBackgroundAgentMemoryManagement)
    var mainAppToDBPPackageDelegate: MainAppToDBPPackageInterface?

    let loginItemsManager: LoginItemsManager = LoginItemsManager()

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
                                                  pixelHandler: DataBrokerProtectionPixelsHandler(),
                                                  redeemUseCase: redeemUseCase)
    }()

    private init() {
        self.redeemUseCase = RedeemUseCase(authenticationService: authenticationService,
                                           authenticationRepository: authenticationRepository)

    }

    public func appDidStart() {
        startLoginItemIfPossible()
    }

    public func shouldAskForInviteCode() -> Bool {
        redeemUseCase.shouldAskForInviteCode()
    }

    public func startLoginItemIfPossible() {
        guard !redeemUseCase.shouldAskForInviteCode() && !DataBrokerDebugFlagBlockScheduler().isFlagOn() else { return }

        //loginItemsManager.enableLoginItems([.dbpBackgroundAgent], log: .dbp)
        ipcConnection.register(machServiceName: Bundle.main.dbpBackgroundAgentBundleId, delegate: self) { success in
            DispatchQueue.main.async {
                if success {
                    os_log("IPC connection with agent succeeded")
                    self.ipcConnection.appDidStart()
                } else {
                    os_log("IPC connection with agent failed")
                }
            }
        }
    }
}

extension DataBrokerProtectionManager: DBPBackgroundAgentToMainAppCommunication {
    public func brokersScanCompleted() {
        os_log("Brokers scan completed called on main app")
        mainAppToDBPPackageDelegate?.brokersScanCompleted()
    }
}

extension DataBrokerProtectionManager: DBPPackageToMainAppInterface {

    public func profileModified() {
        ipcConnection.profileModified()
    }

    public func startScanPressed() {
        ipcConnection.startScanPressed()
    }

    public func startScheduler(showWebView: Bool) {
        ipcConnection.startScheduler(showWebView: showWebView)
    }

    public func stopScheduler() {
        ipcConnection.stopScheduler()
    }

    public func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?) {
        ipcConnection.optOutAllBrokers(showWebView: showWebView, completion: completion)
    }

    public func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?) {
        ipcConnection.scanAllBrokers(showWebView: showWebView, completion: completion)
    }

    public func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?) {
        ipcConnection.runQueuedOperations(showWebView: showWebView, completion: completion)
    }

    public func runAllOperations(showWebView: Bool) {
        ipcConnection.runAllOperations(showWebView: showWebView)
    }

}
