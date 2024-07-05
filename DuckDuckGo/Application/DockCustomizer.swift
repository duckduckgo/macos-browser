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

    private let positionProvider: DockPositionProviding

    init(positionProvider: DockPositionProviding = DockPositionProvider()) {
        self.positionProvider = positionProvider
    }

    private var dockPlistURL: URL = URL(fileURLWithPath: NSString(string: "~/Library/Preferences/com.apple.dock.plist").expandingTildeInPath)

    private var dockPlistDict: [String: AnyObject]? {
        return NSDictionary(contentsOf: dockPlistURL) as? [String: AnyObject]
    }

    // This checks whether the bundle identifier of the current bundle
    // is present in the 'persistent-apps' array of the Dock's plist.
    var isAddedToDock: Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let dockPlistDict = dockPlistDict,
              let persistentApps = dockPlistDict["persistent-apps"] as? [[String: AnyObject]] else {
            return false
        }

        return persistentApps.contains(where: { ($0["tile-data"] as? [String: AnyObject])?["bundle-identifier"] as? String == bundleIdentifier })
    }

    // Adds a dictionary representing the application, either by using an existing 
    // one from 'recent-apps' or creating a new one if the application isn't recently used.
    // It then inserts this dictionary into the 'persistent-apps' list at a position
    // determined by `positionProvider`. Following the plist update, it schedules the Dock
    // to restart after a brief delay to apply the changes.
    @discardableResult
    func addToDock() -> Bool {
        PixelExperiment.fireOnboardingAddToDockRequestedPixel()
        let appPath = Bundle.main.bundleURL.path
        guard !isAddedToDock,
              let bundleIdentifier = Bundle.main.bundleIdentifier,
              var dockPlistDict = dockPlistDict else {
            return false
        }

        var persistentApps = dockPlistDict["persistent-apps"] as? [[String: AnyObject]] ?? []
        let recentApps = dockPlistDict["recent-apps"] as? [[String: AnyObject]] ?? []

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
        dockPlistDict["mod-count"] = ((dockPlistDict["mod-count"] as? Int) ?? 0) + 1 as AnyObject

        do {
            try (dockPlistDict as NSDictionary).write(to: dockPlistURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.restartDock()
            }
            return true
        } catch {
            os_log(.error, "Error writing to Dock plist: %{public}@", error.localizedDescription)
            return false
        }
    }

    private func restartDock() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Dock"]
        task.launch()
    }

    private func makeAppURLs(from persistentApps: [[String: AnyObject]]) -> [URL] {
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
}
