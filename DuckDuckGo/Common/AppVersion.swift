//
//  AppVersion.swift
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

    static let shared = AppVersion()

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var name: String {
        return bundle.object(forInfoDictionaryKey: Bundle.Keys.name) as? String ?? ""
    }

    var identifier: String {
        return bundle.object(forInfoDictionaryKey: Bundle.Keys.identifier) as? String ?? ""
    }

    var majorVersionNumber: String {
        return String(versionNumber.split(separator: ".").first ?? "")
    }

    var versionNumber: String {
        return bundle.object(forInfoDictionaryKey: Bundle.Keys.versionNumber) as? String ?? ""
    }

    var buildNumber: String {
        return bundle.object(forInfoDictionaryKey: Bundle.Keys.buildNumber) as? String ?? ""
    }

}
