//
//  Bundle+NetworkProtectionExtensions.swift
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

extension Bundle {

    var networkExtension: [String: Any] {
        guard let networkExtensionDict = self.infoDictionary!["NetworkExtension"] as? [String: Any] else {
            fatalError("NetworkExtension dict is missing in Info.plist")
        }
        return networkExtensionDict
    }

    /// Retrieves the mach service name from a network extension bundle.
    ///
    var machServiceName: String {
        guard let machServiceName = self.networkExtension["NEMachServiceName"] as? String else {
            fatalError("Mach service name is missing from the Info.plist")
        }
        return machServiceName
    }

    var mainAppBundleIdentifier: String {
        guard let mainAppBundleIdentifier = self.networkExtension["MAIN_BUNDLE_IDENTIFIER"] as? String else {
            fatalError("mainAppBundleIdentifier is missing from the Info.plist")
        }
        return mainAppBundleIdentifier
    }

}
