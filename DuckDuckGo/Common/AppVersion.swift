//
//  AppVersion.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

struct AppVersion {

    struct Keys {
        static let name = kCFBundleNameKey as String
        static let identifier = kCFBundleIdentifierKey as String
        static let buildNumber = kCFBundleVersionKey as String
        static let versionNumber = "CFBundleShortVersionString"
    }

    static let shared = AppVersion()
    
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var name: String {
        return bundle.object(forInfoDictionaryKey: Keys.name) as? String ?? ""
    }

    var identifier: String {
        return bundle.object(forInfoDictionaryKey: Keys.identifier) as? String ?? ""
    }
    
    var majorVersionNumber: String {
        return String(versionNumber.split(separator: ".").first ?? "")
    }

    var versionNumber: String {
        return bundle.object(forInfoDictionaryKey: Keys.versionNumber) as? String ?? ""
    }

    var buildNumber: String {
        return bundle.object(forInfoDictionaryKey: Keys.buildNumber) as? String ?? ""
    }
    
    var versionAndBuildNumber: String {
        return "\(versionNumber).\(buildNumber)"
    }
    
    var localized: String {
        return "\(name) \(versionAndBuildNumber)"
    }
}
