//
//  PreferencesSection.swift
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

import Foundation
import SwiftUI

struct PreferencesSection: Hashable, Identifiable {
    let id: PreferencesSectionIdentifier
    let panes: [PreferencePaneIdentifier]

    @MainActor
    static func defaultSections(includingDuckPlayer: Bool) -> [PreferencesSection] {
        let regularPanes: [PreferencePaneIdentifier] = {
            var panes: [PreferencePaneIdentifier] = [.general, .appearance, .privacy, .autofill, .downloads]
            if includingDuckPlayer {
                panes.append(.duckPlayer)
            }
            if (NSApp.delegate as? AppDelegate)!.internalUserDecider.isInternalUser {
                panes.insert(.sync, at: 1)
            }
            return panes
        }()

        return [
            .init(id: .regularPreferencePanes, panes: regularPanes),
            .init(id: .about, panes: [.about])
        ]
    }
}

enum PreferencesSectionIdentifier: Hashable, CaseIterable {
    case regularPreferencePanes
    case about
}

enum PreferencePaneIdentifier: String, Equatable, Hashable, Identifiable {
    case general
    case sync
    case appearance
    case privacy
    case autofill
    case downloads
    case duckPlayer = "duckplayer"
    case about

    var id: Self {
        self
    }

    init?(url: URL) {
        // manually extract path because URLs such as "about:preferences" can't figure out their host or path
        let path = url.absoluteString.dropping(prefix: URL.preferences.absoluteString + "/")
        self.init(rawValue: path)
    }

    var displayName: String {
        switch self {
        case .general:
            return UserText.general
        case .sync:
            return UserText.sync
        case .appearance:
            return UserText.appearance
        case .privacy:
            return UserText.privacy
        case .autofill:
            return UserText.autofill
        case .downloads:
            return UserText.downloads
        case .duckPlayer:
            return UserText.duckPlayer
        case .about:
            return UserText.about
        }
    }

    var preferenceIconName: String {
        switch self {
        case .general:
            return "Rocket"
        case .sync:
            return "Sync"
        case .appearance:
            return "Appearance"
        case .privacy:
            return "Privacy"
        case .autofill:
            return "Autofill"
        case .downloads:
            return "DownloadsPreferences"
        case .duckPlayer:
            return "DuckPlayerSettings"
        case .about:
            return "About"
        }
    }
}
