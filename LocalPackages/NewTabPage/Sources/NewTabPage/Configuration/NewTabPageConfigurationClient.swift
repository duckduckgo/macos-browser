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
import Common
import os.log
import UserScript
import WebKit

public protocol NewTabPageSectionsVisibilityProviding: AnyObject {
    var isFavoritesVisible: Bool { get set }
    var isPrivacyStatsVisible: Bool { get set }

    var isFavoritesVisiblePublisher: AnyPublisher<Bool, Never> { get }
    var isPrivacyStatsVisiblePublisher: AnyPublisher<Bool, Never> { get }
}

public protocol NewTabPageLinkOpening {
    func openLink(_ target: NewTabPageDataModel.OpenAction.Target) async
}

public final class NewTabPageConfigurationClient: NewTabPageScriptClient {

    public weak var userScriptsSource: NewTabPageUserScriptsSource?

    private var cancellables = Set<AnyCancellable>()
    private let sectionsVisibilityProvider: NewTabPageSectionsVisibilityProviding
    private let customBackgroundProvider: NewTabPageCustomBackgroundProviding
    private let contextMenuPresenter: NewTabPageContextMenuPresenting
    private let linkOpener: NewTabPageLinkOpening

    public init(
        sectionsVisibilityProvider: NewTabPageSectionsVisibilityProviding,
        customBackgroundProvider: NewTabPageCustomBackgroundProviding,
        contextMenuPresenter: NewTabPageContextMenuPresenting = DefaultNewTabPageContextMenuPresenter(),
        linkOpener: NewTabPageLinkOpening
    ) {
        self.sectionsVisibilityProvider = sectionsVisibilityProvider
        self.customBackgroundProvider = customBackgroundProvider
        self.contextMenuPresenter = contextMenuPresenter
        self.linkOpener = linkOpener

        Publishers.Merge(sectionsVisibilityProvider.isFavoritesVisiblePublisher, sectionsVisibilityProvider.isPrivacyStatsVisiblePublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.notifyWidgetConfigsDidChange()
            }
            .store(in: &cancellables)
    }

    enum MessageName: String, CaseIterable {
        case contextMenu
        case initialSetup
        case open
        case reportInitException
        case reportPageException
        case widgetsSetConfig = "widgets_setConfig"
        case widgetsOnConfigUpdated = "widgets_onConfigUpdated"
    }

    public func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageName.contextMenu.rawValue: { [weak self] in try await self?.showContextMenu(params: $0, original: $1) },
            MessageName.initialSetup.rawValue: { [weak self] in try await self?.initialSetup(params: $0, original: $1) },
            MessageName.open.rawValue: { [weak self] in try await self?.open(params: $0, original: $1) },
            MessageName.reportInitException.rawValue: { [weak self] in try await self?.reportException(params: $0, original: $1) },
            MessageName.reportPageException.rawValue: { [weak self] in try await self?.reportException(params: $0, original: $1) },
            MessageName.widgetsSetConfig.rawValue: { [weak self] in try await self?.widgetsSetConfig(params: $0, original: $1) }
        ])
    }

    private func notifyWidgetConfigsDidChange() {
        let widgetConfigs: [NewTabPageDataModel.NewTabPageConfiguration.WidgetConfig] = [
            .init(id: .favorites, isVisible: sectionsVisibilityProvider.isFavoritesVisible),
            .init(id: .privacyStats, isVisible: sectionsVisibilityProvider.isPrivacyStatsVisible)
        ]

        pushMessage(named: MessageName.widgetsOnConfigUpdated.rawValue, params: widgetConfigs)
    }

    @MainActor
    private func showContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params: NewTabPageDataModel.ContextMenuParams = DecodableHelper.decode(from: params) else { return nil }

        let menu = NSMenu()

        for menuItem in params.visibilityMenuItems {
            switch menuItem.id {
            case .favorites:
                let item = NSMenuItem(title: menuItem.title, action: #selector(self.toggleVisibility(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = menuItem.id
                item.state = sectionsVisibilityProvider.isFavoritesVisible ? .on : .off
                menu.addItem(item)
            case .privacyStats:
                let item = NSMenuItem(title: menuItem.title, action: #selector(self.toggleVisibility(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = menuItem.id
                item.state = sectionsVisibilityProvider.isPrivacyStatsVisible ? .on : .off
                menu.addItem(item)
            default:
                break
            }
        }

        if !menu.items.isEmpty {
            contextMenuPresenter.showContextMenu(menu)
        }

        return nil
    }

    @objc private func toggleVisibility(_ sender: NSMenuItem) {
        switch sender.representedObject as? NewTabPageDataModel.WidgetId {
        case .favorites:
            sectionsVisibilityProvider.isFavoritesVisible.toggle()
        case .privacyStats:
            sectionsVisibilityProvider.isPrivacyStatsVisible.toggle()
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

        let customizerData = customBackgroundProvider.customizerData
        let config = NewTabPageDataModel.NewTabPageConfiguration(
            widgets: [
                .init(id: .rmf),
                .init(id: .freemiumPIRBanner),
                .init(id: .nextSteps),
                .init(id: .favorites),
                .init(id: .privacyStats)
            ],
            widgetConfigs: [
                .init(id: .favorites, isVisible: sectionsVisibilityProvider.isFavoritesVisible),
                .init(id: .privacyStats, isVisible: sectionsVisibilityProvider.isPrivacyStatsVisible)
            ],
            env: env,
            locale: Bundle.main.preferredLocalizations.first ?? "en",
            platform: .init(name: "macos"),
            settings: .init(customizerDrawer: .init(state: .enabled)),
            customizer: customizerData
        )
        return config
    }

    @MainActor
    private func widgetsSetConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let widgetConfigs: [NewTabPageDataModel.NewTabPageConfiguration.WidgetConfig] = DecodableHelper.decode(from: params) else {
            return nil
        }
        for widgetConfig in widgetConfigs {
            switch widgetConfig.id {
            case .favorites:
                sectionsVisibilityProvider.isFavoritesVisible = widgetConfig.visibility.isVisible
            case .privacyStats:
                sectionsVisibilityProvider.isPrivacyStatsVisible = widgetConfig.visibility.isVisible
            default:
                break
            }
        }
        return nil
    }

    private func open(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let openAction: NewTabPageDataModel.OpenAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        await linkOpener.openLink(openAction.target)
        return nil
    }

    private func reportException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: String] else { return nil }
        let message = params["message"] ?? ""
        let id = params["id"] ?? ""
        Logger.general.error("New Tab Page error: \("\(id): \(message)", privacy: .public)")
        return nil
    }
}
