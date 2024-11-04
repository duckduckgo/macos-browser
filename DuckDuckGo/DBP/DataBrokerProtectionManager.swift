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
import Freemium

public final class DataBrokerProtectionManager {

    static let shared = DataBrokerProtectionManager()

    private let pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let fakeBrokerFlag: DataBrokerDebugFlag = DataBrokerDebugFlagFakeBroker()

    private lazy var freemiumDBPFirstProfileSavedNotifier: FreemiumDBPFirstProfileSavedNotifier = {
        let freemiumDBPUserStateManager = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp)
        let accountManager = Application.appDelegate.subscriptionManager.accountManager
        let freemiumDBPFirstProfileSavedNotifier = FreemiumDBPFirstProfileSavedNotifier(freemiumDBPUserStateManager: freemiumDBPUserStateManager,
                                                                                        accountManager: accountManager)
        return freemiumDBPFirstProfileSavedNotifier
    }()

    lazy var dataManager: DataBrokerProtectionDataManager = {
        let dataManager = DataBrokerProtectionDataManager(profileSavedNotifier: freemiumDBPFirstProfileSavedNotifier, pixelHandler: pixelHandler, fakeBrokerFlag: fakeBrokerFlag)
        dataManager.delegate = self
        return dataManager
    }()

    private lazy var ipcClient: DataBrokerProtectionIPCClient = {
        let loginItemStatusChecker = LoginItem.dbpBackgroundAgent
        return DataBrokerProtectionIPCClient(machServiceName: Bundle.main.dbpBackgroundAgentBundleId,
                                             pixelHandler: pixelHandler,
                                             loginItemStatusChecker: loginItemStatusChecker)
    }()

    lazy var loginItemInterface: DataBrokerProtectionLoginItemInterface = {
        return DefaultDataBrokerProtectionLoginItemInterface(ipcClient: ipcClient, pixelHandler: pixelHandler)
    }()

    private init() {
        self.authenticationManager = DataBrokerAuthenticationManagerBuilder.buildAuthenticationManager(subscriptionManager: Application.appDelegate.subscriptionManager)
    }

    public func isUserAuthenticated() -> Bool {
        authenticationManager.isUserAuthenticated
    }

    // MARK: - Debugging Features

    public func showAgentIPAddress() {
        ipcClient.openBrowser(domain: "https://www.whatismyip.com")
    }
}

extension DataBrokerProtectionManager: DataBrokerProtectionDataManagerDelegate {

    public func dataBrokerProtectionDataManagerDidUpdateData() {
        loginItemInterface.profileSaved()
    }

    public func dataBrokerProtectionDataManagerDidDeleteData() {
        loginItemInterface.dataDeleted()
    }

    public func dataBrokerProtectionDataManagerWillOpenSendFeedbackForm() {
        NotificationCenter.default.post(name: .OpenUnifiedFeedbackForm, object: nil, userInfo: UnifiedFeedbackSource.userInfo(source: .pir))
    }

    public func isAuthenticatedUser() -> Bool {
        isUserAuthenticated()
    }
}
