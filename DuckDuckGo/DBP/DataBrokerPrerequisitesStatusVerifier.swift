//
//  DataBrokerPrerequisitesStatusVerifier.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Combine
import DataBrokerProtection
import LoginItems
import os.log

enum DataBrokerPrerequisitesStatus {
    case invalidDirectory
    case invalidSystemPermission
    case valid
}

protocol DataBrokerPrerequisitesStatusVerifier: AnyObject {
    func checkStatus() -> DataBrokerPrerequisitesStatus
}

final class DefaultDataBrokerPrerequisitesStatusVerifier: DataBrokerPrerequisitesStatusVerifier {
    private let statusChecker: DBPLoginItemStatusChecker

    init(statusChecker: DBPLoginItemStatusChecker = LoginItem.dbpBackgroundAgent) {
        self.statusChecker = statusChecker
    }

    func checkStatus() -> DataBrokerPrerequisitesStatus {
        if !statusChecker.doesHaveNecessaryPermissions() {
            Logger.dataBrokerProtection.log("Invalid system permissions")
            return .invalidSystemPermission
        } else if !statusChecker.isInCorrectDirectory() {
            Logger.dataBrokerProtection.log("Invalid directory")
            return .invalidDirectory
        } else {
            Logger.dataBrokerProtection.log("Valid system permissions")
            return .valid
        }
    }
}
