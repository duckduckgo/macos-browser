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

    static var config: OSLog {
        Logging.configLoggingEnabled ? Logging.configLog : .disabled
    }

    static var fire: OSLog {
        Logging.fireLoggingEnabled ? Logging.fireLog : .disabled
    }

    static var passwordManager: OSLog {
        Logging.passwordManagerEnabled ? Logging.passwordManagerLog : .disabled
    }

    static var history: OSLog {
        Logging.historyLoggingEnabled ? Logging.historyLog : .disabled
    }

    static var dataImportExport: OSLog {
        Logging.dataImportExportLoggingEnabled ? Logging.dataImportExportLog : .disabled
    }

}

struct Logging {

    fileprivate static let configLoggingEnabled = false
    fileprivate static let configLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Configuration Downloading")

    //TODO put back
    fileprivate static let fireLoggingEnabled = true
    fileprivate static let fireLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Fire")

    fileprivate static let passwordManagerEnabled = false
    fileprivate static let passwordManagerLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Password Manager")

    //TODO put back
    fileprivate static let historyLoggingEnabled = true
    fileprivate static let historyLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "History")

    fileprivate static let dataImportExportLoggingEnabled = false
    fileprivate static let dataImportExportLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Data Import/Export")

}
