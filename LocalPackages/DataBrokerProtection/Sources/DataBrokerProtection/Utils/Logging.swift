//
//  Logging.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

struct Logging {

    static let subsystem = "com.duckduckgo.macos.browser.databroker-protection"

    fileprivate static let dataBrokerProtectionLoggingEnabled = true
    fileprivate static let dataBrokerProtection: OSLog = OSLog(subsystem: subsystem, category: "Data Broker Protection")

    fileprivate static let actionLoggingEnabled = true
    fileprivate static let action: OSLog = OSLog(subsystem: subsystem, category: "Data Broker Protection Action")

    fileprivate static let serviceLoggingEnabled = true
    fileprivate static let service: OSLog = OSLog(subsystem: subsystem, category: "Data Broker Protection Service")

    fileprivate static let errorsLoggingEnabled = true
    fileprivate static let error: OSLog = OSLog(subsystem: subsystem, category: "Data Broker Protection Errors")

    fileprivate static let backgroundAgentLoggingEnabled = true
    fileprivate static let backgroundAgent: OSLog = OSLog(subsystem: subsystem, category: "Data Broker Protection Background Agent")

    fileprivate static let backgroundAgentMemoryManagementLoggingEnabled = true
    fileprivate static let backgroundAgentMemoryManagement: OSLog = OSLog(subsystem: subsystem, category: "Data Broker Protection Background Agent Memory Management")
}

extension OSLog {

    public static var dataBrokerProtection: OSLog {
        Logging.dataBrokerProtectionLoggingEnabled ? Logging.dataBrokerProtection : .disabled
    }

    public static var action: OSLog {
        Logging.actionLoggingEnabled ? Logging.action : .disabled
    }

    public static var service: OSLog {
        Logging.serviceLoggingEnabled ? Logging.service : .disabled
    }

    public static var error: OSLog {
        Logging.errorsLoggingEnabled ? Logging.error : .disabled
    }

    public static var dbpBackgroundAgent: OSLog {
        Logging.backgroundAgentLoggingEnabled ? Logging.backgroundAgent : .disabled
    }

    public static var dbpBackgroundAgentMemoryManagement: OSLog {
        Logging.backgroundAgentMemoryManagementLoggingEnabled ? Logging.backgroundAgentMemoryManagement : .disabled
    }
}
