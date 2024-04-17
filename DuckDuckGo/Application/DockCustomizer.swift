//
//  DockCustomizer.swift
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

final class DockCustomizer {

    /// Adds the current application to the Dock if it's not already there.
    func addCurrentApplicationToDock() {
        let appPath = Bundle.main.bundleURL.path
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let dockPlistPath = NSString(string: "~/Library/Preferences/com.apple.dock.plist").expandingTildeInPath
        let dockPlistURL = URL(fileURLWithPath: dockPlistPath)

        guard var dockPlistDict = NSDictionary(contentsOf: dockPlistURL) as? [String: AnyObject] else {
            return
        }

        var persistentApps = dockPlistDict["persistent-apps"] as? [[String: AnyObject]] ?? []
        let recentApps = dockPlistDict["recent-apps"] as? [[String: AnyObject]] ?? []

        // Check if the application is already in the persistent apps
        let isAppAlreadyInPersistentApps = persistentApps.contains { appDict in
            if let tileData = appDict["tile-data"] as? [String: AnyObject],
               let appBundleIdentifier = tileData["bundle-identifier"] as? String {
                return appBundleIdentifier == bundleIdentifier
            }
            return false
        }

        if isAppAlreadyInPersistentApps {
            return
        }

        // Find the app in recent apps
        if let recentAppIndex = recentApps.firstIndex(where: { appDict in
            if let tileData = appDict["tile-data"] as? [String: AnyObject],
               let appBundleIdentifier = tileData["bundle-identifier"] as? String {
                return appBundleIdentifier == bundleIdentifier
            }
            return false
        }) {
            let appDict = recentApps[recentAppIndex]
            // Move from recent to persistent
            persistentApps.append(appDict)
        } else {
            // Create the dictionary for the current application if not found in recent apps
            let appDict: [String: AnyObject] = ["tile-data": ["file-data": ["_CFURLString": "file://" + appPath + "/", "_CFURLStringType": 0]] as AnyObject]
            persistentApps.append(appDict)
        }

        // Update the plist
        dockPlistDict["persistent-apps"] = persistentApps as AnyObject?
        dockPlistDict["recent-apps"] = recentApps as AnyObject?

        // Mofidy the mod-count
        if let modCount = dockPlistDict["mod-count"] as? Int {
            dockPlistDict["mod-count"] = (modCount + 1) as AnyObject?
        } else {
            assertionFailure("mod-count modification failed")
        }

        // Write
        do {
            try (dockPlistDict as NSDictionary).write(to: dockPlistURL)
        } catch {
            return
        }

        // Restart the Dock to apply changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.restartDock()
        }
    }

    private func restartDock() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Dock"]
        task.launch()
    }
}
