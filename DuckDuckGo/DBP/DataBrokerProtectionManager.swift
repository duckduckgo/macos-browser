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
    private let ipcClient = DataBrokerProtectionIPCClient(machServiceName: Bundle.main.dbpBackgroundAgentBundleId)
    var mainAppToDBPPackageDelegate: MainAppToDBPPackageInterface?

    private let loginItemsManager = LoginItemsManager()

    lazy var dataManager: DataBrokerProtectionDataManager = {
        let dataManager = DataBrokerProtectionDataManager(fakeBrokerFlag: fakeBrokerFlag)
        dataManager.delegate = self
        return dataManager
    }()

    lazy var scheduler = DataBrokerProtectionIPCScheduler(ipcClient: ipcClient)

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

        loginItemsManager.enableLoginItems([.dbpBackgroundAgent], log: .dbp)
    }
}

extension DataBrokerProtectionManager: DataBrokerProtectionDataManagerDelegate {
    public func dataBrokerProtectionDataManagerDidUpdateData() {
        startLoginItemIfPossible()
        scheduler.startScheduler()
    }

    public func dataBrokerProtectionDataManagerDidDeleteData() {
        scheduler.stopScheduler()
        loginItemsManager.disableLoginItems([.dbpBackgroundAgent])
    }
}

extension DataBrokerProtectionManager: DBPBackgroundAgentToMainAppCommunication {
    public func brokersScanCompleted() {
        os_log("Brokers scan completed called on main app")
        mainAppToDBPPackageDelegate?.brokersScanCompleted()
    }
}
