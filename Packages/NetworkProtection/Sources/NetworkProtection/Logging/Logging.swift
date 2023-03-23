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
import os

extension OSLog {

    public static var networkProtection: OSLog {
        Logging.networkProtectionLoggingEnabled ? Logging.networkProtection : .disabled
    }

    public static var networkProtectionKeyManagement: OSLog {
        Logging.networkProtectionKeyManagementLoggingEnabled ? Logging.networkProtectionKeyManagement : .disabled
    }

    public static var networkProtectionBandwidthAnalysis: OSLog {
        Logging.networkProtectionBandwidthAnalysisLoggingEnabled ? Logging.networkProtectionBandwidthAnalysis : .disabled
    }

    public static var networkProtectionConnectionTesterLog: OSLog {
        Logging.networkProtectionConnectionTesterLoggingEnabled ? Logging.networkProtectionConnectionTesterLog : .disabled
    }

    public static var networkProtectionSleepLog: OSLog {
        Logging.networkProtectionSleepLoggingEnabled ? Logging.networkProtectionSleepLog : .disabled
    }
}

struct Logging {

    static let subsystem = Bundle.main.bundleIdentifier ?? "DuckDuckGo"

    fileprivate static let networkProtectionLoggingEnabled = true
    fileprivate static let networkProtection: OSLog = OSLog(subsystem: subsystem, category: "Network Protection")

    fileprivate static let networkProtectionKeyManagementLoggingEnabled = true
    fileprivate static let networkProtectionKeyManagement: OSLog = OSLog(subsystem: subsystem, category: "Network Protection: Key Management")

    fileprivate static let networkProtectionBandwidthAnalysisLoggingEnabled = true
    fileprivate static let networkProtectionBandwidthAnalysis: OSLog = OSLog(subsystem: subsystem, category: "Network Protection: Bandwidth Analysis")

    fileprivate static let networkProtectionConnectionTesterLoggingEnabled = true
    fileprivate static let networkProtectionConnectionTesterLog: OSLog = OSLog(subsystem: subsystem, category: "Network Protection: Connection Tester")

    fileprivate static let networkProtectionSleepLoggingEnabled = true
    fileprivate static let networkProtectionSleepLog: OSLog = OSLog(subsystem: subsystem, category: "Network Protection: Sleep and Wake")
}
