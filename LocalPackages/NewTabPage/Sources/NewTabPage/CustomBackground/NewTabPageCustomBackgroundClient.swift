//
//  NewTabPageCustomBackgroundClient.swift
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

import Common
import Combine
import UserScriptActionsManager
import WebKit

public protocol NewTabPageCustomBackgroundProviding: AnyObject {
    var customizerOpener: NewTabPageCustomizerOpener { get }
    var customizerData: NewTabPageDataModel.CustomizerData { get }

    var background: NewTabPageDataModel.Background { get set }
    var backgroundPublisher: AnyPublisher<NewTabPageDataModel.Background, Never> { get }

    var theme: NewTabPageDataModel.Theme? { get set }
    var themePublisher: AnyPublisher<NewTabPageDataModel.Theme?, Never> { get }

    var userImagesPublisher: AnyPublisher<[NewTabPageDataModel.UserImage], Never> { get }

    @MainActor func presentUploadDialog() async
    func deleteImage(with imageID: String) async

    @MainActor func showContextMenu(for imageID: String, using presenter: NewTabPageContextMenuPresenting) async
}

public final class NewTabPageCustomBackgroundClient: NewTabPageUserScriptClient {

    let model: NewTabPageCustomBackgroundProviding
    let contextMenuPresenter: NewTabPageContextMenuPresenting

    private var cancellables: Set<AnyCancellable> = []

    public init(
        model: NewTabPageCustomBackgroundProviding,
        contextMenuPresenter: NewTabPageContextMenuPresenting = DefaultNewTabPageContextMenuPresenter()
    ) {
        self.model = model
        self.contextMenuPresenter = contextMenuPresenter
        super.init()

        model.backgroundPublisher
            .sink { [weak self] background in
                Task { @MainActor in
                    self?.notifyBackgroundUpdated(background)
                }
            }
            .store(in: &cancellables)

        model.themePublisher
            .sink { [weak self] theme in
                Task { @MainActor in
                    self?.notifyThemeUpdated(theme)
                }
            }
            .store(in: &cancellables)

        model.userImagesPublisher
            .sink { [weak self] images in
                Task { @MainActor in
                    self?.notifyImagesUpdated(images)
                }
            }
            .store(in: &cancellables)

        model.customizerOpener.openSettingsPublisher
            .sink { [weak self] webView in
                Task { @MainActor in
                    self?.openSettings(in: webView)
                }
            }
            .store(in: &cancellables)
    }

    enum MessageName: String, CaseIterable {
        case autoOpen = "customizer_autoOpen"
        case contextMenu = "customizer_contextMenu"
        case deleteImage = "customizer_deleteImage"
        case onBackgroundUpdate = "customizer_onBackgroundUpdate"
        case onImagesUpdate = "customizer_onImagesUpdate"
        case onThemeUpdate = "customizer_onThemeUpdate"
        case setBackground = "customizer_setBackground"
        case setTheme = "customizer_setTheme"
        case upload = "customizer_upload"
    }

    public override func registerMessageHandlers(for userScript: NewTabPageUserScript) {
        userScript.registerMessageHandlers([
            MessageName.contextMenu.rawValue: { [weak self] in try await self?.showContextMenu(params: $0, original: $1) },
            MessageName.deleteImage.rawValue: { [weak self] in try await self?.deleteImage(params: $0, original: $1) },
            MessageName.setBackground.rawValue: { [weak self] in try await self?.setBackground(params: $0, original: $1) },
            MessageName.setTheme.rawValue: { [weak self] in try await self?.setTheme(params: $0, original: $1) },
            MessageName.upload.rawValue: { [weak self] in try await self?.upload(params: $0, original: $1) },
        ])
    }

    @MainActor
    func showContextMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let contextMenu: NewTabPageDataModel.UserImageContextMenu = DecodableHelper.decode(from: params) else {
            return nil
        }
        await model.showContextMenu(for: contextMenu.id, using: contextMenuPresenter)
        return nil
    }

    @MainActor
    func deleteImage(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data: NewTabPageDataModel.DeleteImageData = DecodableHelper.decode(from: params) else {
            return nil
        }
        await model.deleteImage(with: data.id)
        return nil
    }

    @MainActor
    private func setBackground(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data: NewTabPageDataModel.BackgroundData = DecodableHelper.decode(from: params) else {
            return nil
        }
        model.background = data.background
        return nil
    }

    @MainActor
    private func setTheme(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data: NewTabPageDataModel.ThemeData = DecodableHelper.decode(from: params) else {
            return nil
        }
        model.theme = data.theme
        return nil
    }

    @MainActor
    private func upload(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await model.presentUploadDialog()
        return nil
    }

    @MainActor
    private func notifyBackgroundUpdated(_ background: NewTabPageDataModel.Background) {
        pushMessage(named: MessageName.onBackgroundUpdate.rawValue, params: NewTabPageDataModel.BackgroundData(background: background))
    }

    @MainActor
    private func notifyThemeUpdated(_ theme: NewTabPageDataModel.Theme?) {
        pushMessage(named: MessageName.onThemeUpdate.rawValue, params: NewTabPageDataModel.ThemeData(theme: theme))
    }

    @MainActor
    private func notifyImagesUpdated(_ images: [NewTabPageDataModel.UserImage]) {
        pushMessage(named: MessageName.onImagesUpdate.rawValue, params: NewTabPageDataModel.UserImagesData(userImages: images))
    }

    @MainActor
    private func openSettings(in webView: WKWebView) {
        pushMessage(named: MessageName.autoOpen.rawValue, params: nil, to: webView)
    }
}
