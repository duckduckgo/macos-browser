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

    static func isMissionControlActive() -> Bool {
        guard let visibleWindows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, CGWindowID(0)) as? [[CFString: Any]] else {
            assertionFailure("CGWindowListCopyWindowInfo doesn‘t work anymore")
            return false
        }

        let allScreenSizes = NSScreen.screens.map(\.frame.size)

        // Here‘s the trick: normally the Dock App only displays full-screen overlay windows drawing the Dock.
        // When the Mission Control is activated, the Dock presents multiple window tiles for each visible window
        // so here we filter out all the screen-sized windows and if the resulting list is not empty it may
        // mean that Mission Control is active.
        let missionControlWindows = visibleWindows.filter { window in
            windowName(window) == "Dock" && !allScreenSizes.contains(windowSize(window))
        }

        func windowName(_ dict: [CFString: Any]) -> String? {
            dict[kCGWindowOwnerName] as? String
        }
        func windowSize(_ dict: [CFString: Any]) -> NSSize {
            guard let bounds = dict[kCGWindowBounds] as? [String: NSNumber],
                  let width = bounds["Width"]?.intValue,
                  let height = bounds["Height"]?.intValue else { return .zero }
            return NSSize(width: width, height: height)
        }

        return missionControlWindows.count > allScreenSizes.count
    }

}
