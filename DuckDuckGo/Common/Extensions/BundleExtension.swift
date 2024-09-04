//
//  BundleExtension.swift
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

extension Bundle {

    struct Keys {
        static let name = kCFBundleNameKey as String
        static let identifier = kCFBundleIdentifierKey as String
        static let buildNumber = kCFBundleVersionKey as String
        static let versionNumber = "CFBundleShortVersionString"
        static let displayName = "CFBundleDisplayName"
        static let documentTypes = "CFBundleDocumentTypes"
        static let typeExtensions = "CFBundleTypeExtensions"
        static let vpnMenuAgentBundleId = "AGENT_BUNDLE_ID"
        static let vpnMenuAgentProductName = "AGENT_PRODUCT_NAME"

#if NETP_SYSTEM_EXTENSION
        static let notificationsAgentBundleId = "NOTIFICATIONS_AGENT_BUNDLE_ID"
        static let notificationsAgentProductName = "NOTIFICATIONS_AGENT_PRODUCT_NAME"
#endif

        static let ipcAppGroup = "IPC_APP_GROUP"

        static let dbpBackgroundAgentBundleId = "DBP_BACKGROUND_AGENT_BUNDLE_ID"
        static let dbpBackgroundAgentProductName = "DBP_BACKGROUND_AGENT_PRODUCT_NAME"
    }

    var buildNumber: String {
        // swiftlint:disable:next force_cast
        object(forInfoDictionaryKey: Keys.buildNumber) as! String
    }

    var versionNumber: String? {
        object(forInfoDictionaryKey: Keys.versionNumber) as? String
    }

    var vpnMenuAgentBundleId: String {
        guard let bundleID = object(forInfoDictionaryKey: Keys.vpnMenuAgentBundleId) as? String else {
            fatalError("Info.plist is missing \(Keys.vpnMenuAgentBundleId)")
        }
        return bundleID
    }

    var loginItemsURL: URL {
        bundleURL.appendingPathComponent("Contents/Library/LoginItems")
    }

    var vpnMenuAgentURL: URL {
        guard let productName = object(forInfoDictionaryKey: Keys.vpnMenuAgentProductName) as? String else {
            fatalError("Info.plist is missing \(Keys.vpnMenuAgentProductName)")
        }
        return loginItemsURL.appendingPathComponent(productName + ".app")
    }

#if NETP_SYSTEM_EXTENSION
    var notificationsAgentBundleId: String {
        guard let bundleID = object(forInfoDictionaryKey: Keys.notificationsAgentBundleId) as? String else {
            fatalError("Info.plist is missing \(Keys.notificationsAgentBundleId)")
        }
        return bundleID
    }

    var notificationsAgentURL: URL {
        guard let productName = object(forInfoDictionaryKey: Keys.notificationsAgentProductName) as? String else {
            fatalError("Info.plist is missing \(Keys.notificationsAgentProductName)")
        }
        return loginItemsURL.appendingPathComponent(productName + ".app")
    }
#endif

    var dbpBackgroundAgentBundleId: String {
        guard let bundleID = object(forInfoDictionaryKey: Keys.dbpBackgroundAgentBundleId) as? String else {
            fatalError("Info.plist is missing \(Keys.dbpBackgroundAgentBundleId)")
        }
        return bundleID
    }

    var dbpBackgroundAgentURL: URL {
        guard let productName = object(forInfoDictionaryKey: Keys.dbpBackgroundAgentProductName) as? String else {
            fatalError("Info.plist is missing \(Keys.dbpBackgroundAgentProductName)")
        }
        return loginItemsURL.appendingPathComponent(productName + ".app")
    }

    func appGroup(bundle: BundleGroup) -> String {
        let appGroupName = bundle.appGroupKey
        guard let appGroup = object(forInfoDictionaryKey: appGroupName) as? String else {
            fatalError("Info.plist is missing \(appGroupName)")
        }
        return appGroup
    }

    var ipcAppGroupName: String {
        guard let appGroup = object(forInfoDictionaryKey: Keys.ipcAppGroup) as? String else {
            fatalError("Info.plist is missing \(Keys.ipcAppGroup)")
        }
        return appGroup
    }

    var isInApplicationsDirectory: Bool {
        let directoryPaths = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .localDomainMask, true)

        guard let applicationsPath = directoryPaths.first else {
            // Default to true to be safe. In theory this should always return a valid path and the else branch will never be run, but some app logic
            // depends on this check in order to allow users to proceed, so we should avoid blocking them in case this assumption is ever wrong.
            return true
        }

        let path = self.bundlePath
        return path.hasPrefix(applicationsPath)
    }

    var documentTypes: [[String: Any]] {
        infoDictionary?[Keys.documentTypes] as? [[String: Any]] ?? []
    }

    var fileTypeExtensions: Set<String> {
        documentTypes.reduce(into: []) { $0.formUnion($1[Keys.typeExtensions] as? [String] ?? []) }
    }

}

enum BundleGroup {
    case netP
    case ipc
    case dbp
    case subs
    case appConfiguration

    var appGroupKey: String {
        switch self {
        case .dbp:
            return "DBP_APP_GROUP"
        case .ipc:
            return "IPC_APP_GROUP"
        case .netP:
            return "NETP_APP_GROUP"
        case .subs:
            return "SUBSCRIPTION_APP_GROUP"
        case .appConfiguration:
            return "APP_CONFIGURATION_APP_GROUP"
        }
    }
}
