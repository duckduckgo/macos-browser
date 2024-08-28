//
//  LoginItem+DataBrokerProtection.swift
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
import DataBrokerProtection
import os.log

extension LoginItem {

    static let dbpBackgroundAgent = LoginItem(bundleId: Bundle.main.dbpBackgroundAgentBundleId, defaults: .dbp, logger: Logger.dataBrokerProtection)
}

extension LoginItem: DBPLoginItemStatusChecker {

    public func doesHaveNecessaryPermissions() -> Bool {
        return status != .requiresApproval
    }

    public func isInCorrectDirectory() -> Bool {
        guard let appPath = Bundle.main.resourceURL?.deletingLastPathComponent() else { return false }
        let dirPaths = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .localDomainMask, true)
        for path in dirPaths {
            let filePath: URL
            if #available(macOS 13.0, *) {
                filePath = URL(filePath: path)
            } else {
                filePath = URL(fileURLWithPath: path)
            }
            if appPath.absoluteString.hasPrefix(filePath.absoluteString) {
                return true
            }
        }
        return false
    }
}
