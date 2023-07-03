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
        // find an appropriate main App as we‘re running alone from /Library/SystemExtensions
        let mainAppUrls: [URL] = { () -> [URL] in
            if #available(macOS 12.0, *) {
                return NSWorkspace.shared.urlsForApplications(withBundleIdentifier: Bundle.main.mainAppBundleIdentifier)
            }
            return LSCopyApplicationURLsForBundleIdentifier(Bundle.main.mainAppBundleIdentifier as CFString, nil)?.takeRetainedValue() as? [URL] ?? []
        }().filter { appUrl in
            // filter out apps removed to Trash
            !appUrl.path.contains("/.Trash/") // no, FileManager.urls(for: .trashDirectory) doesn‘t work in SysExt
        }

        let version = Bundle.main.versionNumber

        // first try getting an app with matching version
        return mainAppUrls.first(where: { Bundle(url: $0)?.versionNumber == version })
            // try getting an app from /Applications folder
            ?? mainAppUrls.first(where: { $0.path.hasPrefix("/Applications") })
            ?? mainAppUrls.first! // crash if not found

#else // for the AppEx (App Store)
        // Peel off 3 components from /Applications/DuckDuckGo.app/Contents/PlugIns/NetworkProtectionAppExtension.appex
        return Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
#endif
    }

}
