//
//  Logger+Multiple.swift
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
import os.log

extension Logger {
    static var dataImportExport = { Logger(subsystem: "Data Import/Export", category: "") }()
    static var config = { Logger(subsystem: "Configuration Downloading", category: "") }()
    static var autoLock = { Logger(subsystem: "Auto-Lock", category: "") }()
    static var httpsUpgrade = { Logger(subsystem: "HTTPS Upgrade", category: "") }()
    static var atb = { Logger(subsystem: "ATB", category: "") }()
    static var tabSnapshots = { Logger(subsystem: "Tab Snapshots", category: "") }()
    static var tabLazyLoading = { Logger(subsystem: "Lazy Loading", category: "") }()
    static var updates = { Logger(subsystem: "Updates", category: "") }()
}

//extension OSLog {
//fileprivate static let networkProtectionLoginItemLoggingEnabled = false
//fileprivate static let networkProtectionLoginItemLog: OSLog = OSLog(subsystem: subsystem, category: "VPN: Login Item")
//
//fileprivate static let networkProtectionIPCLoginItemLoggingEnabled = false
//fileprivate static let networkProtectionIPCLoginItemLog: OSLog = OSLog(subsystem: subsystem, category: "VPN: IPC (Login Item)")
//
//fileprivate static let networkProtectionMemoryLoggingEnabled = false
//fileprivate static let networkProtectionMemoryLog: OSLog = OSLog(subsystem: subsystem, category: "VPN: Memory")

//    enum AppCategories: String, CaseIterable {
//        case atb = "ATB"
//        case config = "Configuration Downloading"
//        case downloads = "Downloads"
//        case fire = "Fire"
//        case dataImportExport = "Data Import/Export"
//        case pixel = "Pixel"
//        case httpsUpgrade = "HTTPS Upgrade"
//        case favicons = "Favicons"
//        case autoLock = "Auto-Lock"
//        case tabLazyLoading = "Lazy Loading"
//        case autoconsent = "Autoconsent"
//        case bookmarks = "Bookmarks"
//        case attribution = "Ad Attribution"
//        case bitwarden = "Bitwarden"
//        case navigation = "Navigation"
//        case duckPlayer = "Duck Player"
//        case tabSnapshots = "Tab Snapshots"
//        case updates = "Updates"
//        case sync = "Sync"
//        case dbp = "dbp"
//    }
//
//    enum AllCategories {
//        static var allCases: [String] {
//            AppCategories.allCases.map(\.rawValue)
//        }
//    }
//
//    @OSLogWrapper(AppCategories.atb) static var atb
//    @OSLogWrapper(AppCategories.config) static var config
//    @OSLogWrapper(AppCategories.downloads) static var downloads
//    @OSLogWrapper(AppCategories.fire) static var fire
//    @OSLogWrapper(AppCategories.dataImportExport) static var dataImportExport
//    @OSLogWrapper(AppCategories.pixel) static var pixel
//    @OSLogWrapper(AppCategories.httpsUpgrade) static var httpsUpgrade
//    @OSLogWrapper(AppCategories.favicons) static var favicons
//    @OSLogWrapper(AppCategories.autoLock) static var autoLock
//    @OSLogWrapper(AppCategories.tabLazyLoading) static var tabLazyLoading
//    @OSLogWrapper(AppCategories.autoconsent) static var autoconsent
//    @OSLogWrapper(AppCategories.bookmarks) static var bookmarks
//    @OSLogWrapper(AppCategories.attribution) static var attribution
//    @OSLogWrapper(AppCategories.bitwarden) static var bitwarden
//    @OSLogWrapper(AppCategories.navigation) static var navigation
//    @OSLogWrapper(AppCategories.duckPlayer) static var duckPlayer
//    @OSLogWrapper(AppCategories.tabSnapshots) static var tabSnapshots
//    @OSLogWrapper(AppCategories.updates) static var updates
//    @OSLogWrapper(AppCategories.sync) static var sync
//    @OSLogWrapper(AppCategories.dbp) static var dbp
//
//    // Debug->Logging categories will only be enabled for one day
//    @UserDefaultsWrapper(key: .loggingEnabledDate, defaultValue: .distantPast)
//    private static var loggingEnabledDate: Date
//    private static var isLoggingEnabledToday: Bool {
//        NSCalendar.current.isDate(Date(), inSameDayAs: loggingEnabledDate)
//    }
//
//    @UserDefaultsWrapper(key: .loggingCategories, defaultValue: [])
//    private static var loggingCategoriesSetting: [String] {
//        didSet {
//            loggingEnabledDate = Date()
//        }
//    }
//    static var loggingCategories: Set<String> {
//        get {
//            guard isLoggingEnabledToday else { return [] }
//            return Set(loggingCategoriesSetting)
//        }
//        set {
//            loggingCategoriesSetting = Array(newValue)
//            enabledLoggingCategories = loggingCategories
//        }
//    }
//
//    static let isRunningInDebugEnvironment: Bool = {
//        ProcessInfo().environment[ProcessInfo.Constants.osActivityMode] == ProcessInfo.Constants.debug
//            || ProcessInfo().environment[ProcessInfo.Constants.osActivityDtMode] == ProcessInfo.Constants.yes
//    }()
//
//    static let subsystem = Bundle.main.bundleIdentifier!
//
//}
//
//extension ProcessInfo {
//    enum Constants {
//        static let osActivityMode = "OS_ACTIVITY_MODE"
//        static let osActivityDtMode = "OS_ACTIVITY_DT_MODE"
//        static let debug = "debug"
//        static let yes = "YES"
//    }
//}
//
//extension OSLog.OSLogWrapper {
//
//    private static let enableLoggingCategoriesOnce: Void = {
//#if CI
//        OSLog.enabledLoggingCategories = Set(OSLog.AllCategories.allCases)
//#else
//        OSLog.enabledLoggingCategories = OSLog.loggingCategories
//#endif
//    }()
//
//    init(_ category: OSLog.AppCategories) {
//        _=Self.enableLoggingCategoriesOnce
//        self.init(rawValue: category.rawValue)
//    }
//
//}
//
//func logOrAssertionFailure(_ message: String) {
//#if DEBUG && !CI
//    assertionFailure(message)
//#else
//    os_log("\(, privacy: .public)", type: .error, message)
//#endif
//}
//
//#if DEBUG
//
//func breakByRaisingSigInt(_ description: String, file: StaticString = #file, line: Int = #line) {
//    let fileLine = "\(("\(file)" as NSString).lastPathComponent):\(line)"
//    os_log("""
//
//
//    ------------------------------------------------------------------------------------------------------
//        BREAK at %s:
//    ------------------------------------------------------------------------------------------------------
//
//    %s
//
//        Hit Continue (^⌘Y) to continue program execution
//    ------------------------------------------------------------------------------------------------------
//
//    """, type: .debug, fileLine, description.components(separatedBy: "\n").map { "    " + $0.trimmingWhitespace() }.joined(separator: "\n"))
//    raise(SIGINT)
//}
//
//// get symbol from stack trace for a caller of a calling method
//func callingSymbol() -> String {
//    let stackTrace = Thread.callStackSymbols
//    // find `callingSymbol` itself or dispatch_once_callout
//    var callingSymbolIdx = stackTrace.firstIndex(where: { $0.contains("_dispatch_once_callout") })
//    ?? stackTrace.firstIndex(where: { $0.contains("callingSymbol") })!
//    // procedure calling `callingSymbol`
//    callingSymbolIdx += 1
//
//    var symbolName: String
//    repeat {
//        // caller for the procedure
//        callingSymbolIdx += 1
//        let line = stackTrace[callingSymbolIdx].replacingOccurrences(of: Bundle.main.executableURL!.lastPathComponent, with: "DDG")
//        symbolName = String(line.split(separator: " ", maxSplits: 3)[3]).components(separatedBy: " + ")[0]
//    } while stackTrace[callingSymbolIdx - 1].contains(symbolName.dropping(suffix: "To")) // skip objc wrappers
//
//    return symbolName
//}
//
//#endif
