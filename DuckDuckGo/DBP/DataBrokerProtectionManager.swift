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

#if DBP

import Foundation
import BrowserServicesKit
import DataBrokerProtection
import LoginItems
import Common

public final class DataBrokerProtectionManager {

    static let shared = DataBrokerProtectionManager()

    private let pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()
    private let authenticationRepository: AuthenticationRepository = KeychainAuthenticationData()
    private let authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService()
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker()
    private let dataBrokerProtectionWaitlistDataSource: WaitlistActivationDateStore = DefaultWaitlistActivationDateStore(source: .dbp)

    lazy var dataManager: DataBrokerProtectionDataManager = {
        let dataManager = DataBrokerProtectionDataManager(fakeBrokerFlag: fakeBrokerFlag)
        dataManager.delegate = self
        return dataManager
    }()

    private lazy var ipcClient = DataBrokerProtectionIPCClient(machServiceName: Bundle.main.dbpBackgroundAgentBundleId, pixelHandler: pixelHandler)

    lazy var scheduler: DataBrokerProtectionLoginItemScheduler = {

        let ipcScheduler = DataBrokerProtectionIPCScheduler(ipcClient: ipcClient)

        return DataBrokerProtectionLoginItemScheduler(ipcScheduler: ipcScheduler)
    }()

    private init() {
        self.redeemUseCase = RedeemUseCase(authenticationService: authenticationService,
                                           authenticationRepository: authenticationRepository)

    }

    public func shouldAskForInviteCode() -> Bool {
        redeemUseCase.shouldAskForInviteCode()
    }

    // MARK: - Debugging Features

    public func showAgentIPAddress() {
        ipcClient.openBrowser(domain: "https://www.whatismyip.com")
    }
}

extension DataBrokerProtectionManager: DataBrokerProtectionDataManagerDelegate {
    public func dataBrokerProtectionDataManagerDidUpdateData() {
        scheduler.startScheduler()

        let dbpDateStore = DefaultWaitlistActivationDateStore(source: .dbp)
        dbpDateStore.setActivationDateIfNecessary()
    }

    public func dataBrokerProtectionDataManagerDidDeleteData() {
        scheduler.stopScheduler()
    }
}

#endif
