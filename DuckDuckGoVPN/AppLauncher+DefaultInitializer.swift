//
//  AppLauncher+DefaultInitializer.swift
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

import AppLauncher
import Foundation

/// Includes a convenience default initializer for `AppLauncher` that's specific to this App target.
///
extension AppLauncher {
    convenience init() {
        let appBundleURL: URL
        let parentBundlePath = "../../../../"

        if #available(macOS 13, *) {
            appBundleURL = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        } else {
            appBundleURL = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        }

        self.init(appBundleURL: appBundleURL)
    }
}
