//
//  NewTabPageConfigurationClient.swift
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

import AppKit
import Combine
import UserScript

final class NewTabPageConfigurationClient: NewTabPageScriptClient {

    let appearancePreferences: AppearancePreferences
    weak var userScriptsSource: NewTabPageUserScriptsSource?

    private var cancellables = Set<AnyCancellable>()

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

    enum MessageNames: String, CaseIterable {
        case contextMenu
        case initialSetup
        case widgetsSetConfig = "widgets_setConfig"
        case widgetsOnConfigUpdated = "widgets_onConfigUpdated"
    }

    func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageNames.contextMenu.rawValue: { [weak self] in try await self?.showContextMenu(params: $0, original: $1) },
            MessageNames.initialSetup.rawValue: { [weak self] in try await self?.initialSetup(params: $0, original: $1) },
            MessageNames.widgetsSetConfig.rawValue: { [weak self] in try await self?.widgetsSetConfig(params: $0, original: $1) }
        ])
    }

    private func notifyWidgetConfigsDidChange() {
        let widgetConfigs: [NewTabPageUserScript.NewTabPageConfiguration.WidgetConfig] = [
            .init(id: "favorites", isVisible: appearancePreferences.isFavoriteVisible),
            .init(id: "privacyStats", isVisible: appearancePreferences.isRecentActivityVisible)
        ]

        userScriptsSource?.userScripts.forEach { userScript in
            pushMessage(named: MessageNames.widgetsOnConfigUpdated.rawValue, params: widgetConfigs, for: userScript)
        }
    }

    @MainActor
    private func showContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: Any] else { return nil }

        guard let menuItems = params["visibilityMenuItems"] as? [[String: String]] else {
            return nil
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

        return nil
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

    @MainActor
    private func initialSetup(params: Any, original: WKScriptMessage) async throws -> Encodable? {
#if DEBUG || REVIEW
        let env = "development"
#else
        let env = "production"
#endif
        return NewTabPageUserScript.NewTabPageConfiguration(
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

    @MainActor
    private func widgetsSetConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [[String: String]] else { return nil }
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
        return nil
    }
}

extension NewTabPageUserScript {

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

                var isVisible: Bool {
                    self == .visible
                }
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
}
