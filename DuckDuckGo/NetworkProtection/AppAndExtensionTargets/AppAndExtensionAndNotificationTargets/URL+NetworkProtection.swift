//
//  URL+NetworkProtection.swift
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

import AppKit
import Foundation

extension URL {

    public static var mainAppBundleURL: URL {
#if !NETWORK_EXTENSION // for the Main or Launcher Agent app
        final class BundleHelper {}
        return Bundle(for: BundleHelper.self).bundleURL

#elseif NETP_SYSTEM_EXTENSION // for the System Extension (Developer ID)
        guard #available(macOS 12.0, *) else {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: Bundle.mainAppBundleIdentifier)!
        }

        let applicationsPath = (FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first?.path ?? "") + "/"
        // if multiple apps found prefer the one in the /Applications dir
        return NSWorkspace.shared.urlsForApplications(withBundleIdentifier: Bundle.mainAppBundleIdentifier)
            .sorted(by: { (url, _) in url.path.hasPrefix(applicationsPath) })
            .first!

#else // for the AppEx (App Store)
        // Peel off 3 components from /Applications/DuckDuckGo.app/Contents/PlugIns/NetworkProtectionAppExtension.appex
        return Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
#endif
    }

}
