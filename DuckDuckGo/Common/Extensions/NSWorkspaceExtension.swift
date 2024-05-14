//
//  NSWorkspaceExtension.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import CoreGraphics

extension NSWorkspace {

    func application(toOpen url: URL) -> String? {
        guard let appURL = urlForApplication(toOpen: url),
              let bundle = Bundle(url: appURL)
        else { return nil }

        return bundle.displayName
    }

    /// Detect if macOS Mission Control (three-finger swipe up to show the Spaces) is currently active
    static func isMissionControlActive() -> Bool {
        guard let visibleWindows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, CGWindowID(0)) as? [[CFString: Any]] else {
            assertionFailure("CGWindowListCopyWindowInfo doesn‘t work anymore")
            return false
        }

        // Here‘s the trick: normally the Dock App only displays full-screen overlay windows drawing the Dock.
        // When the Mission Control is activated, the Dock presents multiple window tiles for each visible window
        // so here we filter out all the screen-sized windows and if the resulting list is not empty it may
        // mean that Mission Control is active.
        let dockAppWindows = visibleWindows.filter { window in
            window.ownerName == "Dock"
        }
        // filter out wallpaper windows
        var missionControlWindows = dockAppWindows.filter { window in
            window.name?.hasPrefix("Wallpaper") != true
        }
        // filter out the Dock drawing windows
        for screen in NSScreen.screens {
            if let idx = missionControlWindows.firstIndex(where: { window in window.size == screen.frame.size }) {
                missionControlWindows.remove(at: idx)
            }
        }

        return missionControlWindows.count > 0
    }

    @available(macOS, obsoleted: 14.0, message: "This needs to be removed as it‘s no longer necessary.")
    @nonobjc func urls(forApplicationsWithBundleId bundleId: String) -> [URL] {
        if #available(macOS 12.0, *) {
            return self.urlsForApplications(withBundleIdentifier: bundleId)
        }
        return LSCopyApplicationURLsForBundleIdentifier(bundleId as CFString, nil)?.takeRetainedValue() as? [URL] ?? []
    }

}

extension NSWorkspace.OpenConfiguration {

    convenience init(newInstance: Bool, environment: [String: String]? = nil) {
        self.init()
        self.createsNewApplicationInstance = newInstance
        if let environment {
            self.environment = environment
        }
    }

}

private extension [CFString: Any] {

    var name: String? {
        self[kCGWindowName] as? String
    }

    var ownerName: String? {
        self[kCGWindowOwnerName] as? String
    }

    var size: NSSize {
        guard let bounds = self[kCGWindowBounds] as? [String: NSNumber],
              let width = bounds["Width"]?.intValue,
              let height = bounds["Height"]?.intValue else { return .zero }
        return NSSize(width: width, height: height)
    }

}
