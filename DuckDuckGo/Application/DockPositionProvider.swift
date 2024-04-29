//
//  DockPositionProvider.swift
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

enum DockApp: String {
    case chrome = "com.google.chrome"
    case firefox = "org.mozilla.firefox"
    case edge = "com.microsoft.msedge"
    case brave = "com.brave.browser"
    case opera = "com.operasoftware.opera"
    case arc = "company.thebrowser.browser"
    case safari = "com.apple.safari"
    case unknown = ""
}

protocol DockPositionProviding {

    func newDockIndex(from currentApps: [DockApp]) -> Int

}

/// Class to determine the new dock position
final class DockPositionProvider: DockPositionProviding {

    private let preferredOrder: [DockApp] = [
        .chrome,
        .firefox,
        .edge,
        .brave,
        .opera,
        .arc,
        .safari
    ]

    /// Determines the new dock index for a new app based on the preferred order
    /// - Parameter currentApps: The list of currently docked apps
    /// - Returns: The index at which the new app should be placed
    func newDockIndex(from currentApps: [DockApp]) -> Int {
        for app in preferredOrder {
            if let position = currentApps.firstIndex(of: app) {
                return position + 1
            }
        }

        return currentApps.count
    }
}
