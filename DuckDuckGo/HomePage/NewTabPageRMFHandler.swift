//
//  NewTabPageRMFHandler.swift
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
import RemoteMessaging
import UserScript

protocol NewTabPageScriptClient {
    func registerMessageHandlers(for userScript: SubfeatureWithExternalMessageHandling)
}

extension NewTabPageScriptClient {
    func pushMessage(named method: String, params: Encodable?, for userScript: SubfeatureWithExternalMessageHandling) {
        guard let webView = userScript.webView else {
            return
        }
        userScript.broker?.push(method: method, params: params, for: userScript, into: webView)
    }
}

final class NewTabPageRMFHandler: NewTabPageScriptClient {

    let activeRemoteMessageModel: ActiveRemoteMessageModel
    weak var userScriptsSource: NewTabPageUserScriptsSource?

    private var cancellables = Set<AnyCancellable>()

    init(activeRemoteMessageModel: ActiveRemoteMessageModel) {
        self.activeRemoteMessageModel = activeRemoteMessageModel

        activeRemoteMessageModel.$remoteMessage.dropFirst()
            .sink { [weak self] remoteMessage in
                self?.notifyRemoteMessageDidChange(remoteMessage)
            }
            .store(in: &cancellables)
    }

    enum MessageNames: String, CaseIterable {
        case rmfGetData = "rmf_getData"
        case rmfOnDataUpdate = "rmf_onDataUpdate"
        case rmfDismiss = "rmf_dismiss"
        case rmfPrimaryAction = "rmf_primaryAction"
        case rmfSecondaryAction = "rmf_secondaryAction"
    }

    func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageNames.rmfGetData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageNames.rmfOnDataUpdate.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageNames.rmfDismiss.rawValue: { [weak self] in try await self?.dismiss(params: $0, original: $1) },
            MessageNames.rmfPrimaryAction.rawValue: { [weak self] in try await self?.primaryAction(params: $0, original: $1) },
            MessageNames.rmfSecondaryAction.rawValue: { [weak self] in try await self?.secondaryAction(params: $0, original: $1) }
        ])
    }

    @MainActor
    private func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let remoteMessage = activeRemoteMessageModel.remoteMessage else {
            return NewTabPageUserScript.RMFData(content: nil)
        }

        return NewTabPageUserScript.RMFData(content: .init(remoteMessage))
    }

    private func dismiss(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let paramsDict = params as? [String: Any], let id = paramsDict["id"] as? String else {
            return nil
        }
        assert(id == activeRemoteMessageModel.remoteMessage?.id)
        await activeRemoteMessageModel.dismissRemoteMessage(with: .close)
        return nil
    }

    private func primaryAction(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let paramsDict = params as? [String: Any], let id = paramsDict["id"] as? String else {
            return nil
        }
        assert(id == activeRemoteMessageModel.remoteMessage?.id)
        switch activeRemoteMessageModel.remoteMessage?.content {
        case let .bigSingleAction(_, _, _, _, primaryAction):
            print(primaryAction)
            await activeRemoteMessageModel.dismissRemoteMessage(with: .action)
        case let .bigTwoAction(_, _, _, _, primaryAction, _, _):
            print(primaryAction)
            await activeRemoteMessageModel.dismissRemoteMessage(with: .primaryAction)
        default:
            break
        }
        return nil
    }

    private func secondaryAction(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let paramsDict = params as? [String: Any], let id = paramsDict["id"] as? String else {
            return nil
        }
        assert(id == activeRemoteMessageModel.remoteMessage?.id)
        switch activeRemoteMessageModel.remoteMessage?.content {
        case let .bigTwoAction(_, _, _, _, _, secondaryAction, _):
            print(secondaryAction)
        default:
            break
        }
        await activeRemoteMessageModel.dismissRemoteMessage(with: .secondaryAction)
        return nil
    }

    private func notifyRemoteMessageDidChange(_ remoteMessage: RemoteMessageModel?) {
        let data: NewTabPageUserScript.RMFData = {
            guard let remoteMessage else {
                return .init(content: nil)
            }
            return .init(content: NewTabPageUserScript.RMFMessage(remoteMessage))
        }()

        userScriptsSource?.userScripts.forEach { userScript in
            pushMessage(named: MessageNames.rmfOnDataUpdate.rawValue, params: data, for: userScript)
        }
    }
}

extension NewTabPageUserScript.RMFMessage {
    init?(_ remoteMessageModel: RemoteMessageModel) {
        guard let modelType = remoteMessageModel.content, modelType.isSupported else {
            return nil
        }

        switch modelType {
        case let .small(titleText, descriptionText):
            self = .small(.init(id: remoteMessageModel.id, titleText: titleText, descriptionText: descriptionText))

        case let .medium(titleText, descriptionText, placeholder):
            self = .medium(.init(id: remoteMessageModel.id, titleText: titleText, descriptionText: descriptionText, icon: .init(placeholder)))

        case let .bigSingleAction(titleText, descriptionText, placeholder, primaryActionText, _):
            self = .bigSingleAction(.init(id: remoteMessageModel.id, titleText: titleText, descriptionText: descriptionText, icon: .init(placeholder), primaryActionText: primaryActionText))

        case let .bigTwoAction(titleText, descriptionText, placeholder, primaryActionText, _, secondaryActionText, _):
            self = .bigTwoAction(.init(id: remoteMessageModel.id, titleText: titleText, descriptionText: descriptionText, icon: .init(placeholder), primaryActionText: primaryActionText, secondaryActionText: secondaryActionText))

        default:
            return nil
        }
    }
}

extension NewTabPageUserScript {

    struct RMFData: Encodable {
        var content: RMFMessage?
    }

    enum RMFMessage: Encodable {
        case small(SmallMessage), medium(MediumMessage), bigSingleAction(BigSingleActionMessage), bigTwoAction(BigTwoActionMessage)

        func encode(to encoder: any Encoder) throws {
            try message.encode(to: encoder)
        }

        var message: Encodable {
            switch self {
            case .small(let message):
                return message
            case .medium(let message):
                return message
            case .bigSingleAction(let message):
                return message
            case .bigTwoAction(let message):
                return message
            }
        }
    }

    struct SmallMessage: Encodable {
        let messageType = "small"

        var id: String
        var titleText: String
        var descriptionText: String
    }

    struct MediumMessage: Encodable {
        let messageType = "medium"

        var id: String
        var titleText: String
        var descriptionText: String
        var icon: RMFIcon
    }

    struct BigSingleActionMessage: Encodable {
        let messageType = "big_single_action"

        var id: String
        var titleText: String
        var descriptionText: String
        var icon: RMFIcon
        var primaryActionText: String
    }

    struct BigTwoActionMessage: Encodable {
        let messageType = "big_two_action"

        var id: String
        var titleText: String
        var descriptionText: String
        var icon: RMFIcon
        var primaryActionText: String
        var secondaryActionText: String
    }

    enum RMFIcon: String, Encodable {
        case announce = "Announce"
        case ddgAnnounce = "DDGAnnounce"
        case criticalUpdate = "CriticalUpdate"
        case appUpdate = "AppUpdate"
        case privacyPro = "PrivacyPro"

        init(_ placeholder: RemotePlaceholder) {
            switch placeholder {
            case .announce:
                self = .announce
            case .ddgAnnounce:
                self = .ddgAnnounce
            case .criticalUpdate:
                self = .criticalUpdate
            case .appUpdate:
                self = .appUpdate
            case .privacyShield:
                self = .privacyPro
            default:
                self = .ddgAnnounce
            }
        }
    }
}
