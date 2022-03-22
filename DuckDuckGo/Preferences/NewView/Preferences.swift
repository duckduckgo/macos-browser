//
//  Preferences.swift
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

import SwiftUI

enum Preferences {
    enum Const {
        enum Fonts {

            static let popUpButton: NSFont = {
                if #available(macOS 11.0, *) {
                    let titleFont = NSFont.preferredFont(forTextStyle: .title1, options: [:])
                    return .systemFont(ofSize: titleFont.pointSize, weight: .semibold)
                } else {
                    return .systemFont(ofSize: 22, weight: .semibold)
                }
            }()

            static let sideBarItem: Font = {
                if #available(macOS 11.0, *) {
                    return .body.weight(.medium)
                } else {
                    return .system(size: 13, weight: .medium)
                }
            }()

            static let preferencePaneTitle: Font = {
                if #available(macOS 11.0, *) {
                    return .title2.weight(.semibold)
                } else {
                    return .system(size: 17, weight: .semibold)
                }
            }()

            static let preferencePaneSectionHeader: Font = {
                if #available(macOS 11.0, *) {
                    return .title3.weight(.semibold)
                } else {
                    return .system(size: 15, weight: .semibold)
                }
            }()

            static let preferencePaneCaption: Font = {
                if #available(macOS 11.0, *) {
                    return .subheadline
                } else {
                    return .system(size: 10)
                }
            }()
        }
    }
}

enum PreferencesSectionIdentifier: Hashable, CaseIterable {
    case regularPreferencePanes
    case about
}

enum PreferencePaneIdentifier: Hashable, Identifiable {
    case defaultBrowser
    case appearance
    case privacy
    case loginsPlus
    case downloads
    case about
    
    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .defaultBrowser:
            return UserText.defaultBrowser
        case .appearance:
            return UserText.appearance
        case .privacy:
            return UserText.privacy
        case .loginsPlus:
            return UserText.loginsPlus
        case .downloads:
            return UserText.downloads
        case .about:
            return UserText.about
        }
    }

    var preferenceIconName: String {
        switch self {
        case .defaultBrowser:
            return "DefaultBrowser"
        case .appearance:
            return "Appearance"
        case .privacy:
            return "Privacy"
        case .loginsPlus:
            return "Logins+"
        case .downloads:
            return "DownloadsPreferences"
        case .about:
            return "About"
        }
    }
}

struct PreferencesSection: Hashable, Identifiable {
    let id: PreferencesSectionIdentifier
    let panes: [PreferencePaneIdentifier]
    
    static let defaultSections: [PreferencesSection] = [
        .init(
            id: .regularPreferencePanes,
            panes: [.defaultBrowser, .appearance, .privacy, .loginsPlus, .downloads]
        ),
        .init(
            id: .about,
            panes: [.about]
        )
    ]
}
