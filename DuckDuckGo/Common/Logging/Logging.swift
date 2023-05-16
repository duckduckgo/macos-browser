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

import Common
import Foundation
import os.log // swiftlint:disable:this enforce_os_log_wrapper

extension OSLog {

    enum AppCategories: String, CaseIterable {
        case atb = "ATB"
        case config = "Configuration Downloading"
        case fire = "Fire"
        case passwordManager = "Password Manager"
        case history = "History"
        case dataImportExport = "Data Import/Export"
        case pixel = "Pixel"
        case contentBlocking = "Content Blocking"
        case httpsUpgrade = "HTTPS Upgrade"
        case favicons = "Favicons"
        case autoLock = "Auto-Lock"
        case tabLazyLoading = "Lazy Loading"
        case autoconsent = "Autoconsent"
        case bookmarks = "Bookmarks"
        case attribution = "Ad Attribution"
        case bitwarden = "Bitwarden"
        case navigation = "Navigation"
        case duckPlayer = "Duck Player"
        case sync = "Sync"
    }
    enum AllCategories {
        static var allCases: [String] {
            Categories.allCases.map(\.rawValue) + AppCategories.allCases.map(\.rawValue)
        }
    }

    @OSLogWrapper(.atb) static var atb
    @OSLogWrapper(.config) static var config
    @OSLogWrapper(.fire) static var fire
    @OSLogWrapper(.history) static var history
    @OSLogWrapper(.dataImportExport) static var dataImportExport
    @OSLogWrapper(.pixel) static var pixel
    @OSLogWrapper(.contentBlocking) static var contentBlocking
    @OSLogWrapper(.httpsUpgrade) static var httpsUpgrade
    @OSLogWrapper(.favicons) static var favicons
    @OSLogWrapper(.autoLock) static var autoLock
    @OSLogWrapper(.tabLazyLoading) static var tabLazyLoading
    @OSLogWrapper(.autoconsent) static var autoconsent
    @OSLogWrapper(.bookmarks) static var bookmarks
    @OSLogWrapper(.attribution) static var attribution
    @OSLogWrapper(.bitwarden) static var bitwarden
    @OSLogWrapper(.navigation) static var navigation
    @OSLogWrapper(.duckPlayer) static var duckPlayer
    @OSLogWrapper(.sync) static var sync

    // Debug->Logging categories will only be enabled for one day
    @UserDefaultsWrapper(key: .loggingEnabledDate, defaultValue: .distantPast)
    private static var loggingEnabledDate: Date
    private static var isLoggingEnabledToday: Bool {
        NSCalendar.current.isDate(Date(), inSameDayAs: loggingEnabledDate)
    }

    @UserDefaultsWrapper(key: .loggingCategories, defaultValue: [])
    private static var loggingCategoriesSetting: [String] {
        didSet {
            loggingEnabledDate = Date()
        }
    }
    static var loggingCategories: Set<String> {
        get {
            guard isLoggingEnabledToday else { return [] }
            return Set(loggingCategoriesSetting)
        }
        set {
            loggingCategoriesSetting = Array(newValue)
            enabledLoggingCategories = loggingCategories
        }
    }

    static let isRunningInDebugEnvironment: Bool = {
        ProcessInfo().environment[ProcessInfo.Constants.osActivityMode] == ProcessInfo.Constants.debug
            || ProcessInfo().environment[ProcessInfo.Constants.osActivityDtMode] == ProcessInfo.Constants.yes
    }()

    static let subsystem = Bundle.main.bundleIdentifier!

}

extension ProcessInfo {
    enum Constants {
        static let osActivityMode = "OS_ACTIVITY_MODE"
        static let osActivityDtMode = "OS_ACTIVITY_DT_MODE"
        static let debug = "debug"
        static let yes = "YES"
    }
}

extension OSLog.OSLogWrapper {

    private static let enableLoggingCategoriesOnce: Void = {
#if CI
        OSLog.enabledLoggingCategories = Set(OSLog.AllCategories.allCases)
#else
        OSLog.enabledLoggingCategories = OSLog.loggingCategories
#endif
    }()

    init(_ category: OSLog.AppCategories) {
        _=Self.enableLoggingCategoriesOnce
        self.init(rawValue: category.rawValue)
    }

}

func logOrAssertionFailure(_ message: StaticString, args: CVarArg...) {
#if DEBUG
    assertionFailure("\(message)")
#else
    os_log("BWManager: Wrong handler", type: .error)
#endif
}
