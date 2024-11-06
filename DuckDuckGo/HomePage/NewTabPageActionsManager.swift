//
//  NewTabPageActionsManager.swift
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
import Combine
import PixelKit
import Common
import os.log

protocol NewTabPageActionsManaging {
    var configuration: NewTabPageConfiguration { get }

    /// It is called in case of error loading the pages
    func reportException(with param: [String: String])
}

struct NewTabPageConfiguration: Encodable {
    var widgets: [Widget]
    var widgetConfigs: [WidgetConfig]
    var env: String
    var locale: String
    var platform: Platform

    struct Widget: Encodable {
        var id: String
    }

    struct WidgetConfig: Encodable {

        enum WidgetVisibility: String, Encodable {
            case visible, hidden
        }

        init(id: String, isVisible: Bool) {
            self.id = id
            self.visibility = isVisible ? .visible : .hidden
        }

        var id: String
        var visibility: WidgetVisibility
    }

    struct Platform: Encodable {
        var name: String
    }
}

final class NewTabPageActionsManager: NewTabPageActionsManaging {

    private let appearancePreferences: AppearancePreferences
    private var cancellables = Set<AnyCancellable>()

    init(appearancePreferences: AppearancePreferences) {
        self.appearancePreferences = appearancePreferences
    }

    var configuration: NewTabPageConfiguration {
#if DEBUG || REVIEW
        let env = "development"
#else
        let env = "production"
#endif
        return .init(
            widgets: [
                .init(id: "rmf"),
                .init(id: "favorites"),
                .init(id: "privacyStats")
            ],
            widgetConfigs: [
                .init(id: "favorites", isVisible: appearancePreferences.isFavoriteVisible),
                .init(id: "privacyStats", isVisible: appearancePreferences.isRecentActivityVisible)
            ],
            env: env,
            locale: Bundle.main.preferredLocalizations.first ?? "en",
            platform: .init(name: "macos")
        )
    }

    func reportException(with param: [String: String]) {
        let message = param["message"] ?? ""
        let id = param["id"] ?? ""
        Logger.general.error("New Tab Page error: \("\(id): \(message)", privacy: .public)")
    }
}
