//
//  NewTabPageRMFClient.swift
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
import RemoteMessaging
import UserScriptActionsManager
import WebKit

public enum RemoteMessageButton: Equatable {
    case close, action, primaryAction, secondaryAction
}

public final class NewTabPageRMFClient: NewTabPageUserScriptClient {

    let remoteMessageProvider: NewTabPageActiveRemoteMessageProviding

    private var cancellables = Set<AnyCancellable>()

    public init(remoteMessageProvider: NewTabPageActiveRemoteMessageProviding) {
        self.remoteMessageProvider = remoteMessageProvider
        super.init()

        remoteMessageProvider.newTabPageRemoteMessagePublisher
            .sink { [weak self] remoteMessage in
                self?.notifyRemoteMessageDidChange(remoteMessage)
            }
            .store(in: &cancellables)
    }

    enum MessageName: String, CaseIterable {
        case rmfGetData = "rmf_getData"
        case rmfOnDataUpdate = "rmf_onDataUpdate"
        case rmfDismiss = "rmf_dismiss"
        case rmfPrimaryAction = "rmf_primaryAction"
        case rmfSecondaryAction = "rmf_secondaryAction"
    }

    public override func registerMessageHandlers(for userScript: NewTabPageUserScript) {
        userScript.registerMessageHandlers([
            MessageName.rmfGetData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.rmfDismiss.rawValue: { [weak self] in try await self?.dismiss(params: $0, original: $1) },
            MessageName.rmfPrimaryAction.rawValue: { [weak self] in try await self?.primaryAction(params: $0, original: $1) },
            MessageName.rmfSecondaryAction.rawValue: { [weak self] in try await self?.secondaryAction(params: $0, original: $1) }
        ])
    }

    @MainActor
    private func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let remoteMessage = remoteMessageProvider.newTabPageRemoteMessage else {
            return NewTabPageDataModel.RMFData(content: nil)
        }

        return NewTabPageDataModel.RMFData(content: .init(remoteMessage))
    }

    private func dismiss(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let remoteMessageParams: NewTabPageDataModel.RemoteMessageParams = DecodableHelper.decode(from: params),
              remoteMessageParams.id == remoteMessageProvider.newTabPageRemoteMessage?.id
        else {
            return nil
        }

        await remoteMessageProvider.handleAction(nil, andDismissUsing: .close)
        return nil
    }

    private func primaryAction(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let remoteMessageParams: NewTabPageDataModel.RemoteMessageParams = DecodableHelper.decode(from: params),
              remoteMessageParams.id == remoteMessageProvider.newTabPageRemoteMessage?.id
        else {
            return nil
        }

        switch remoteMessageProvider.newTabPageRemoteMessage?.content {
        case let .bigSingleAction(_, _, _, _, primaryAction):
            await remoteMessageProvider.handleAction(primaryAction, andDismissUsing: .action)
        case let .bigTwoAction(_, _, _, _, primaryAction, _, _):
            await remoteMessageProvider.handleAction(primaryAction, andDismissUsing: .primaryAction)
        default:
            break
        }
        return nil
    }

    private func secondaryAction(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let remoteMessageParams: NewTabPageDataModel.RemoteMessageParams = DecodableHelper.decode(from: params),
              remoteMessageParams.id == remoteMessageProvider.newTabPageRemoteMessage?.id
        else {
            return nil
        }

        switch remoteMessageProvider.newTabPageRemoteMessage?.content {
        case let .bigTwoAction(_, _, _, _, _, _, secondaryAction):
            await remoteMessageProvider.handleAction(secondaryAction, andDismissUsing: .secondaryAction)
        default:
            break
        }
        return nil
    }

    private func notifyRemoteMessageDidChange(_ remoteMessage: RemoteMessageModel?) {
        let data: NewTabPageDataModel.RMFData = {
            guard let remoteMessage, remoteMessageProvider.isMessageSupported(remoteMessage) else {
                return .init(content: nil)
            }
            return .init(content: NewTabPageDataModel.RMFMessage(remoteMessage))
        }()

        pushMessage(named: MessageName.rmfOnDataUpdate.rawValue, params: data)
    }
}
