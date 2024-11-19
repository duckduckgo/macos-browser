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
import RemoteMessaging
import UserScript

protocol NewTabPageActiveRemoteMessageProviding {
    var remoteMessage: RemoteMessageModel? { get set }
    var remoteMessagePublisher: AnyPublisher<RemoteMessageModel?, Never> { get }

    func dismissRemoteMessage(with action: RemoteMessageViewModel.ButtonAction?) async
}

extension ActiveRemoteMessageModel: NewTabPageActiveRemoteMessageProviding {
    var remoteMessagePublisher: AnyPublisher<RemoteMessageModel?, Never> {
        $remoteMessage.dropFirst().eraseToAnyPublisher()
    }
}

final class NewTabPageRMFClient: NewTabPageScriptClient {

    let remoteMessageProvider: NewTabPageActiveRemoteMessageProviding
    weak var userScriptsSource: NewTabPageUserScriptsSource?

    private let openURLHandler: (URL) -> Void
    private var cancellables = Set<AnyCancellable>()

    init(remoteMessageProvider: NewTabPageActiveRemoteMessageProviding, openURLHandler: @escaping (URL) -> Void) {
        self.remoteMessageProvider = remoteMessageProvider
        self.openURLHandler = openURLHandler

        remoteMessageProvider.remoteMessagePublisher
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

    func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageName.rmfGetData.rawValue: { [weak self] in try await self?.getData(params: $0, original: $1) },
            MessageName.rmfDismiss.rawValue: { [weak self] in try await self?.dismiss(params: $0, original: $1) },
            MessageName.rmfPrimaryAction.rawValue: { [weak self] in try await self?.primaryAction(params: $0, original: $1) },
            MessageName.rmfSecondaryAction.rawValue: { [weak self] in try await self?.secondaryAction(params: $0, original: $1) }
        ])
    }

    @MainActor
    private func getData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let remoteMessage = remoteMessageProvider.remoteMessage else {
            return NewTabPageUserScript.RMFData(content: nil)
        }

        return NewTabPageUserScript.RMFData(content: .init(remoteMessage))
    }

    private func dismiss(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let paramsDict = params as? [String: Any],
              let id = paramsDict["id"] as? String,
              id == remoteMessageProvider.remoteMessage?.id
        else {
            return nil
        }

        await remoteMessageProvider.dismissRemoteMessage(with: .close)
        return nil
    }

    private func primaryAction(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let paramsDict = params as? [String: Any],
              let id = paramsDict["id"] as? String,
              id == remoteMessageProvider.remoteMessage?.id
        else {
            return nil
        }

        switch remoteMessageProvider.remoteMessage?.content {
        case let .bigSingleAction(_, _, _, _, primaryAction):
            handleAction(remoteAction: primaryAction)
            await remoteMessageProvider.dismissRemoteMessage(with: .action)
        case let .bigTwoAction(_, _, _, _, primaryAction, _, _):
            handleAction(remoteAction: primaryAction)
            await remoteMessageProvider.dismissRemoteMessage(with: .primaryAction)
        default:
            break
        }
        return nil
    }

    private func secondaryAction(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let paramsDict = params as? [String: Any],
              let id = paramsDict["id"] as? String,
              id == remoteMessageProvider.remoteMessage?.id
        else {
            return nil
        }

        switch remoteMessageProvider.remoteMessage?.content {
        case let .bigTwoAction(_, _, _, _, _, _, secondaryAction):
            handleAction(remoteAction: secondaryAction)
            await remoteMessageProvider.dismissRemoteMessage(with: .secondaryAction)
        default:
            break
        }
        return nil
    }

    private func handleAction(remoteAction: RemoteAction) {
        switch remoteAction {
        case .url(let value), .share(let value, _), .survey(let value):
            if let url = URL.makeURL(from: value) {
                openURLHandler(url)
            }
        case .appStore:
            openURLHandler(.appStore)
        default:
            break
        }
    }

    private func notifyRemoteMessageDidChange(_ remoteMessage: RemoteMessageModel?) {
        let data: NewTabPageUserScript.RMFData = {
            guard let remoteMessage else {
                return .init(content: nil)
            }
            return .init(content: NewTabPageUserScript.RMFMessage(remoteMessage))
        }()

        pushMessage(named: MessageName.rmfOnDataUpdate.rawValue, params: data)
    }
}

extension NewTabPageUserScript {

    struct RMFData: Encodable {
        var content: RMFMessage?
    }

    enum RMFMessage: Encodable, Equatable {
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

    struct SmallMessage: Encodable, Equatable {
        let messageType = "small"

        var id: String
        var titleText: String
        var descriptionText: String
    }

    struct MediumMessage: Encodable, Equatable {
        let messageType = "medium"

        var id: String
        var titleText: String
        var descriptionText: String
        var icon: RMFIcon
    }

    struct BigSingleActionMessage: Encodable, Equatable {
        let messageType = "big_single_action"

        var id: String
        var titleText: String
        var descriptionText: String
        var icon: RMFIcon
        var primaryActionText: String
    }

    struct BigTwoActionMessage: Encodable, Equatable {
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
