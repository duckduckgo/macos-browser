//
//  LoginItem+NetworkProtection.swift
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
import LoginItems
import NetworkProtection
import os.log

extension LoginItem {
    static let vpnMenu = LoginItem(bundleId: Bundle.main.vpnMenuAgentBundleId,
                                   defaults: .netP,
                                   logger: Logger.networkProtection)
#if NETP_SYSTEM_EXTENSION
    static let notificationsAgent = LoginItem(bundleId: Bundle.main.notificationsAgentBundleId,
                                              defaults: .netP,
                                              logger: Logger.networkProtection)
#endif

}

extension LoginItemsManager {
    static var networkProtectionLoginItems: Set<LoginItem> {
        var items: Set<LoginItem> = [.vpnMenu]
#if NETP_SYSTEM_EXTENSION
        items.insert(.notificationsAgent)
#endif
        return items
    }
}
