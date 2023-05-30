//
//  Logging.swift
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
import os // swiftlint:disable:this enforce_os_log_wrapper

extension OSLog {

    public static var networkProtectionLoginItemLog: OSLog {
        Logging.networkProtectionLoginItemLoggingEnabled ? Logging.networkProtectionLoginItemLog : .disabled
    }

    public static var networkProtectionIPCLoginItemLog: OSLog {
        Logging.networkProtectionIPCLoginItemLoggingEnabled ? Logging.networkProtectionIPCLoginItemLog : .disabled
    }

    public static var networkProtectionMemoryLog: OSLog {
        Logging.networkProtectionMemoryLoggingEnabled ? Logging.networkProtectionMemoryLog : .disabled
    }
}

struct Logging {

    static let subsystem = Bundle.main.bundleIdentifier ?? "DuckDuckGo"

    fileprivate static let networkProtectionLoginItemLoggingEnabled = false
    fileprivate static let networkProtectionLoginItemLog: OSLog = OSLog(subsystem: subsystem, category: "Network Protection: Login Item")

    fileprivate static let networkProtectionIPCLoginItemLoggingEnabled = false
    fileprivate static let networkProtectionIPCLoginItemLog: OSLog = OSLog(subsystem: subsystem, category: "Network Protection: IPC (Login Item)")

    fileprivate static let networkProtectionMemoryLoggingEnabled = false
    fileprivate static let networkProtectionMemoryLog: OSLog = OSLog(subsystem: subsystem, category: "Network Protection: Memory")
}
