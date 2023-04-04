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

    static var pixel: OSLog {
        Logging.pixelLoggingEnabled ? Logging.pixelLog : .disabled
    }

    static var autoconsent: OSLog {
        Logging.autoconsentLoggingEnabled ? Logging.autoconsentLog : .disabled
    }

    static var contentBlocking: OSLog {
        Logging.contentBlockingLoggingEnabled ? Logging.contentBlockingLog : .disabled
    }

    static var favicons: OSLog {
        Logging.faviconLoggingEnabled ? Logging.faviconLog : .disabled
    }

    static var autoLock: OSLog {
        Logging.autoLockLoggingEnabled ? Logging.autoLockLog : .disabled
    }

    static var tabLazyLoading: OSLog {
        Logging.tabLazyLoaderLoggingEnabled ? Logging.tabLazyLoaderLog : .disabled
    }

    static var bookmarks: OSLog {
        Logging.bookmarksLoggingEnabled ? Logging.bookmarksLog : .disabled
    }

    static var bitwarden: OSLog {
        Logging.bitwardenLoggingEnabled ? Logging.bitwardenLog : .disabled
    }

    static var attribution: OSLog {
        Logging.attributionLoggingEnabled ? Logging.attributionLog : .disabled
    }

    static var atb: OSLog {
        Logging.atbLoggingEnabled ? Logging.atbLog : .disabled
    }

    static var navigation: OSLog {
        Logging.navigationLoggingEnabled ? Logging.navigationLog : .disabled
    }

}

struct Logging {

#if DEBG
    private static let defaultLoggingEnabled: Bool = {
        ProcessInfo().environment["OS_ACTIVITY_MODE"] == "debug"
    }()
#else
    private static let defaultLoggingEnabled = false
#endif

    fileprivate static let atbLoggingEnabled = defaultLoggingEnabled
    fileprivate static let atbLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "ATB")

    fileprivate static let configLoggingEnabled = defaultLoggingEnabled
    fileprivate static let configLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Configuration Downloading")

    fileprivate static let fireLoggingEnabled = defaultLoggingEnabled
    fileprivate static let fireLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Fire")

    fileprivate static let passwordManagerEnabled = defaultLoggingEnabled
    fileprivate static let passwordManagerLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Password Manager")

    fileprivate static let historyLoggingEnabled = defaultLoggingEnabled
    fileprivate static let historyLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "History")

    fileprivate static let dataImportExportLoggingEnabled = defaultLoggingEnabled
    fileprivate static let dataImportExportLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Data Import/Export")

    fileprivate static let pixelLoggingEnabled = defaultLoggingEnabled
    fileprivate static let pixelLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Pixel")

    fileprivate static let contentBlockingLoggingEnabled = defaultLoggingEnabled
    fileprivate static let contentBlockingLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Content Blocking")

    fileprivate static let faviconLoggingEnabled = defaultLoggingEnabled
    fileprivate static let faviconLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Favicons")

    fileprivate static let autoLockLoggingEnabled = defaultLoggingEnabled
    fileprivate static let autoLockLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Auto-Lock")

    fileprivate static let tabLazyLoaderLoggingEnabled = defaultLoggingEnabled
    fileprivate static let tabLazyLoaderLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Lazy Loading")

    fileprivate static let autoconsentLoggingEnabled = defaultLoggingEnabled
    fileprivate static let autoconsentLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Autoconsent")

    fileprivate static let bookmarksLoggingEnabled = defaultLoggingEnabled
    fileprivate static let bookmarksLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Bookmarks")

    fileprivate static let attributionLoggingEnabled = defaultLoggingEnabled
    fileprivate static let attributionLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Ad Attribution")

    fileprivate static let bitwardenLoggingEnabled = defaultLoggingEnabled
    fileprivate static let bitwardenLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Bitwarden")

    fileprivate static let navigationLoggingEnabled = defaultLoggingEnabled
    fileprivate static let navigationLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "Navigation")

}

func logOrAssertionFailure(_ message: StaticString, args: CVarArg...) {
#if DEBUG
    assertionFailure("\(message)")
#else
    os_log("BWManager: Wrong handler", type: .error)
#endif
}
