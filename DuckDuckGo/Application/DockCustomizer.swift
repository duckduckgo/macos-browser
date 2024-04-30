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
import Common

protocol DockCustomization {
    var isAddedToDock: Bool { get }

    @discardableResult
    func addToDock() -> Bool
}

final class DockCustomizer: DockCustomization {

    static func appDict(appPath: String, bundleIdentifier: String) -> [String: AnyObject] {
        return ["tile-type": "file-tile" as AnyObject,
                "tile-data": [
                    "dock-extra": 0 as AnyObject,
                    "file-type": 1 as AnyObject,
                    "file-data": [
                        "_CFURLString": "file://" + appPath + "/",
                        "_CFURLStringType": 15
                    ],
                    "file-label": "DuckDuckGo" as AnyObject,
                    "bundle-identifier": bundleIdentifier as AnyObject,
                    "is-beta": 0 as AnyObject
                ] as AnyObject
        ]
    }

    let positionProvider: DockPositionProviding = DockPositionProvider(defaultBrowserProvider: SystemDefaultBrowserProvider())

    var isAddedToDock: Bool {
        // Checks if the current application is already in the Dock
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        guard let dockPlistDict = dockPlistDict else {
            return false
        }

        if let persistentApps = dockPlistDict["persistent-apps"] as? [[String: AnyObject]] {
            return persistentApps.contains { appDict in
                if let tileData = appDict["tile-data"] as? [String: AnyObject],
                   let appBundleIdentifier = tileData["bundle-identifier"] as? String {
                    return appBundleIdentifier == bundleIdentifier
                }
                return false
            }
        }

        return false
    }

    private var dockPlistURL: URL {
        let dockPlistPath = NSString(string: "~/Library/Preferences/com.apple.dock.plist").expandingTildeInPath
        return URL(fileURLWithPath: dockPlistPath)
    }

    private var dockPlistDict: [String: AnyObject]? {
        return NSDictionary(contentsOf: dockPlistURL) as? [String: AnyObject]
    }

    @discardableResult
    func addToDock() -> Bool {
        let appPath = Bundle.main.bundleURL.path

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        guard var dockPlistDict = dockPlistDict else {
            return false
        }

        var persistentApps = dockPlistDict["persistent-apps"] as? [[String: AnyObject]] ?? []
        let recentApps = dockPlistDict["recent-apps"] as? [[String: AnyObject]] ?? []

        // Check if the application is already in the Dock
        if isAddedToDock {
            return false
        }

        let appDict: [String: AnyObject]
        // Find the app in recent apps
        if let recentAppIndex = recentApps.firstIndex(where: { appDict in
            if let tileData = appDict["tile-data"] as? [String: AnyObject],
               let appBundleIdentifier = tileData["bundle-identifier"] as? String {
                return appBundleIdentifier == bundleIdentifier
            }
            return false
        }) {
            // Use existing dictonary from recentApps
            appDict = recentApps[recentAppIndex]
        } else {
            // Create the dictionary for the current application if not found in recent apps
            appDict = Self.appDict(appPath: appPath, bundleIdentifier: bundleIdentifier)
        }

        // Insert to persistent apps
        let index = positionProvider.newDockIndex(from: makeAppURLs(from: persistentApps))
        persistentApps.insert(appDict, at: index)

        // Update the plist
        dockPlistDict["persistent-apps"] = persistentApps as AnyObject?
        dockPlistDict["recent-apps"] = recentApps as AnyObject?

        // Update mod-count
        if let modCount = dockPlistDict["mod-count"] as? Int {
            dockPlistDict["mod-count"] = modCount + 1 as AnyObject?
        } else {
            assertionFailure("mod-count modification failed")
        }

        // Write changes to the plist
        do {
            try (dockPlistDict as NSDictionary).write(to: dockPlistURL)
        } catch {
            os_log(.error, "Error writing to Dock plist: %{public}@", error.localizedDescription)
            return false
        }

        // Restart the Dock to apply changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.restartDock()
        }

        return true
    }

    private func restartDock() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Dock"]
        task.launch()
    }
}

extension DockCustomizer {

    func makeAppURLs(from persistentApps: [[String: AnyObject]]) -> [URL] {
        return persistentApps.compactMap { appDict in
            if let tileData = appDict["tile-data"] as? [String: AnyObject],
               let appBundleIdentifier = tileData["file-data"] as? [String: AnyObject],
               let urlString = appBundleIdentifier["_CFURLString"] as? String,
               let url = URL(string: urlString) {
                return url
            } else {
                return nil
            }
        }
    }

}
