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

protocol NewTabPageActionsManaging: AnyObject {
    var configuration: NewTabPageUserScript.NewTabPageConfiguration { get }

    func registerUserScript(_ userScript: NewTabPageUserScript)

    func getFavorites() -> NewTabPageUserScript.FavoritesData
    func getFavoritesConfig() -> NewTabPageUserScript.WidgetConfig

    func getPrivacyStats() -> NewTabPageUserScript.PrivacyStatsData
    func getPrivacyStatsConfig() -> NewTabPageUserScript.WidgetConfig

    /// It is called in case of error loading the pages
    func reportException(with params: [String: String])
    func showContextMenu(with params: [String: Any])
    func updateWidgetConfigs(with params: [[String: String]])
}

final class NewTabPageActionsManager: NewTabPageActionsManaging {

    private let appearancePreferences: AppearancePreferences
    private var cancellables = Set<AnyCancellable>()
    private var userScripts = NSHashTable<NewTabPageUserScript>.weakObjects()

    init(appearancePreferences: AppearancePreferences) {
        self.appearancePreferences = appearancePreferences

        appearancePreferences.$isFavoriteVisible.dropFirst().removeDuplicates().asVoid()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.notifyWidgetConfigsDidChange()
            }
            .store(in: &cancellables)

        appearancePreferences.$isRecentActivityVisible.dropFirst().removeDuplicates().asVoid()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.notifyWidgetConfigsDidChange()
            }
            .store(in: &cancellables)
    }

    func registerUserScript(_ userScript: NewTabPageUserScript) {
        userScripts.add(userScript)
    }

    private func notifyWidgetConfigsDidChange() {
        userScripts.allObjects.forEach { userScript in
            userScript.notifyWidgetConfigsDidChange(widgetConfigs: [
                .init(id: "favorites", isVisible: appearancePreferences.isFavoriteVisible),
                .init(id: "privacyStats", isVisible: appearancePreferences.isRecentActivityVisible)
            ])
        }
    }

    var configuration: NewTabPageUserScript.NewTabPageConfiguration {
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

    func getFavorites() -> NewTabPageUserScript.FavoritesData {
        // implementation TBD
        .init(favorites: [])
    }

    func getFavoritesConfig() -> NewTabPageUserScript.WidgetConfig {
        // implementation TBD
        .init(animation: .auto, expansion: .collapsed)
    }

    func getPrivacyStats() -> NewTabPageUserScript.PrivacyStatsData {
        // implementation TBD
        .init(totalCount: 0, trackerCompanies: [])
    }

    func getPrivacyStatsConfig() -> NewTabPageUserScript.WidgetConfig {
        // implementation TBD
        .init(animation: .auto, expansion: .collapsed)
    }

    func showContextMenu(with params: [String: Any]) {
        guard let menuItems = params["visibilityMenuItems"] as? [[String: String]] else {
            return
        }
        let menu = NSMenu()

        for menuItem in menuItems {
            guard let title = menuItem["title"], let id = menuItem["id"] else {
                continue
            }
            switch id {
            case "favorites":
                let item = NSMenuItem(title: title, action: #selector(toggleVisibility(_:)), representedObject: id)
                    .targetting(self)
                item.state = appearancePreferences.isFavoriteVisible ? .on : .off
                menu.addItem(item)
            case "privacyStats":
                let item = NSMenuItem(title: title, action: #selector(toggleVisibility(_:)), representedObject: id)
                    .targetting(self)
                item.state = appearancePreferences.isRecentActivityVisible ? .on : .off
                menu.addItem(item)
            default:
                break
            }
        }

        if !menu.items.isEmpty {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    @objc private func toggleVisibility(_ sender: NSMenuItem) {
        switch sender.representedObject as? String {
        case "favorites":
            appearancePreferences.isFavoriteVisible.toggle()
        case "privacyStats":
            appearancePreferences.isRecentActivityVisible.toggle()
        default:
            break
        }
    }

    func updateWidgetConfigs(with params: [[String: String]]) {
        for param in params {
            guard let id = param["id"], let visibility = param["visibility"] else {
                continue
            }
            let isVisible = NewTabPageUserScript.NewTabPageConfiguration.WidgetConfig.WidgetVisibility(rawValue: visibility)?.isVisible == true
            switch id {
            case "favorites":
                appearancePreferences.isFavoriteVisible = isVisible
            case "privacyStats":
                appearancePreferences.isRecentActivityVisible = isVisible
            default:
                break
            }
        }
    }

    func reportException(with params: [String: String]) {
        let message = params["message"] ?? ""
        let id = params["id"] ?? ""
        Logger.general.error("New Tab Page error: \("\(id): \(message)", privacy: .public)")
    }
}
