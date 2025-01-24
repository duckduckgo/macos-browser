//
//  NewTabPageFreemiumDBPClient.swift
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

import Combine
import Common
import UserScriptActionsManager
import WebKit

public protocol NewTabPageFreemiumDBPBannerProviding {

    var bannerMessage: NewTabPageDataModel.FreemiumPIRBannerMessage? { get }

    var bannerMessagePublisher: AnyPublisher<NewTabPageDataModel.FreemiumPIRBannerMessage?, Never> { get }

    func dismiss() async

    func action() async
}

public final class NewTabPageFreemiumDBPClient: NewTabPageUserScriptClient {

    let freemiumDBPBannerProvider: NewTabPageFreemiumDBPBannerProviding

    private var cancellables = Set<AnyCancellable>()

    public init(provider: NewTabPageFreemiumDBPBannerProviding) {
        self.freemiumDBPBannerProvider = provider
        super.init()

        freemiumDBPBannerProvider.bannerMessagePublisher
            .sink { [weak self] message in
                self?.notifyMessageDidChange(message)
            }
            .store(in: &cancellables)
    }

    enum MessageName: String, CaseIterable {
        case getData = "freemiumPIRBanner_getData"
        case onDataUpdate = "freemiumPIRBanner_onDataUpdate"
        case dismiss = "freemiumPIRBanner_dismiss"
        case action = "freemiumPIRBanner_action"
    }

    public override func registerMessageHandlers(for userScript: NewTabPageUserScript) {
        userScript.registerMessageHandlers([
            MessageName.action.rawValue: { [weak self] in try await self?.action(params: $0, original: $1) },
            MessageName.dismiss.rawValue: { [weak self] in try await self?.dismiss(params: $0, original: $1) },
            MessageName.getData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
        ])
    }

    @MainActor
    private func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let message = freemiumDBPBannerProvider.bannerMessage else {
            return NewTabPageDataModel.FreemiumPIRBannerMessageData(content: nil)
        }

        return NewTabPageDataModel.FreemiumPIRBannerMessageData(content: message)
    }

    private func dismiss(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await freemiumDBPBannerProvider.dismiss()
        return nil
    }

    private func action(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await freemiumDBPBannerProvider.action()
        return nil
    }

    private func notifyMessageDidChange(_ message: NewTabPageDataModel.FreemiumPIRBannerMessage?) {
        pushMessage(named: MessageName.onDataUpdate.rawValue, params: NewTabPageDataModel.FreemiumPIRBannerMessageData(content: message))
    }
}
