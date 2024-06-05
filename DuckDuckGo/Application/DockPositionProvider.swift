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

enum DockApp: String, CaseIterable {
    case chrome = "/Applications/Google Chrome.app/"
    case firefox = "/Applications/Firefox.app/"
    case edge = "/Applications/Microsoft Edge.app/"
    case brave = "/Applications/Brave Browser.app/"
    case opera = "/Applications/Opera.app/"
    case arc = "/Applications/Arc.app/"
    case safari = "/Applications/Safari.app/"
    case safariLong = "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/"

    var url: URL? {
        return URL(string: "file://" + self.rawValue)
    }
}

protocol DockPositionProviding {
    func newDockIndex(from currentAppURLs: [URL]) -> Int
}

/// Class to determine the best positioning in the Dock
final class DockPositionProvider: DockPositionProviding {

    private let preferredOrder: [DockApp] = [
        .chrome,
        .firefox,
        .edge,
        .brave,
        .opera,
        .arc,
        .safari,
        .safariLong
    ]

    private var defaultBrowserProvider: DefaultBrowserProvider

    init(defaultBrowserProvider: DefaultBrowserProvider = SystemDefaultBrowserProvider()) {
        self.defaultBrowserProvider = defaultBrowserProvider
    }

    /// Determines the new dock index for a new app based on the default browser or preferred order
    func newDockIndex(from currentAppURLs: [URL]) -> Int {
        // Place next to the default browser
        if !defaultBrowserProvider.isDefault,
           let defaultBrowserURL = defaultBrowserProvider.defaultBrowserURL,
           let position = currentAppURLs.firstIndex(of: defaultBrowserURL) {
            return position + 1
        }

        // Place based on the preferred order
        for app in preferredOrder {
            if let appUrl = app.url, let position = currentAppURLs.firstIndex(of: appUrl) {
                return position + 1
            }
        }

        // Otherwise, place at the end
        return currentAppURLs.count
    }
}
