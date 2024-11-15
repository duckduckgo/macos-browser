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
    }

    func registerMessageHandlers(for userScript: any SubfeatureWithExternalMessageHandling) {
        userScript.registerMessageHandlers([
            MessageNames.rmfGetData.rawValue: { [weak self] in try await self?.rmfGetData(params: $0, original: $1) }
        ])
    }

    @MainActor
    private func rmfGetData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let data = NewTabPageUserScript.RMFData(content: getRemoteMessage())
        return data
    }

    func getRemoteMessage() -> NewTabPageUserScript.RMFMessage? {
        .small(.init(descriptionText: "Hello, this is a description", id: "hejka", titleText: "Hello I'm a title"))
    }


    private func notifyRemoteMessageDidChange(_ remoteMessage: RemoteMessageModel?) {
        let data = NewTabPageUserScript.RMFData(content: .small(.init(descriptionText: "Hello, this is a description", id: "hejka", titleText: "Hello I'm a title")))

        userScriptsSource?.userScripts.forEach { userScript in
            pushMessage(named: MessageNames.rmfGetData.rawValue, params: data, for: userScript)
        }
    }

    func notifyRemoteMessageDidChange(_ remoteMessageData: NewTabPageUserScript.RMFData?) {

    }
}
