//
//  NSWorkspaceExtension.swift
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

import AppKit

extension NSWorkspace {

    func openApplication(at url: URL,
                         with arguments: [String] = [],
                         newInstance: Bool = false,
                         userPrompts: Bool = true,
                         completionHandler: ((NSRunningApplication?, Error?) -> Void)? = nil) {

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = arguments
        config.createsNewApplicationInstance = newInstance
        config.promptsUserIfNeeded = userPrompts
        NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: completionHandler)
    }

    func runningBrowserInstance() -> NSRunningApplication? {
        let pid = NSRunningApplication.current.processIdentifier
        let fm = FileManager.default
        return self.runningApplications
            .first(where: {
                    $0.bundleIdentifier == Bundle.main.bundleIdentifier
                        && $0.processIdentifier != pid
                        && $0.bundleURL != nil
                        && fm.extendedAttributeValue(forKey: AppTabMaker.appTabURLKey, at: $0.bundleURL!) as URL? == nil
            })
    }

    func browserAppURL() -> URL? {
        let bundleId = Bundle.main.bundleIdentifier! as CFString
        let urls = LSCopyApplicationURLsForBundleIdentifier(bundleId, nil)?.takeRetainedValue() as? [URL]
        let fm = FileManager.default
        return urls?.filter { url in
            fm.extendedAttributeValue(forKey: AppTabMaker.appTabURLKey, at: url) as URL? == nil
        }.sorted { lhs, rhs in
            (lhs.appendingPathComponent("Contents/Info.plist").modificationDate ?? .distantPast)
                < (rhs.appendingPathComponent("Contents/Info.plist").modificationDate ?? .distantPast)
        }.last
    }

}
