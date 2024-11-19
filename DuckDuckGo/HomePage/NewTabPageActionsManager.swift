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
import RemoteMessaging
import Common
import os.log

/**
 * This protocol describes a feature or set of features that use HTML New Tab Page.
 *
 * A class implementing this protocol can register handlers for a subset of
 * `NewTabPageUserScript`'s messages, allowing for better separation of concerns
 * by having e.g. a class responsible for handling Favorites messages, a class responsible
 * for handling RMF messages, etc.
 *
 * Objects implementing this protocol are added to `NewTabPageActionsManager`.
 */
protocol NewTabPageScriptClient: AnyObject {
    /**
     * Handle to the object that returns the list of all living `NewTabPageUserScript` instances.
     */
    var userScriptsSource: NewTabPageUserScriptsSource? { get set }

    /**
     * This function should be implemented to add all message handlers to the provided `userScript`.
     */
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

protocol NewTabPageActionsManaging: AnyObject {
    func registerUserScript(_ userScript: NewTabPageUserScript)
}

protocol NewTabPageUserScriptsSource: AnyObject {
    var userScripts: [SubfeatureWithExternalMessageHandling] { get }
}

final class NewTabPageActionsManager: NewTabPageActionsManaging, NewTabPageUserScriptsSource {

    private let newTabPageScriptClients: [NewTabPageScriptClient]

    private var cancellables = Set<AnyCancellable>()
    private var userScriptsHandles = NSHashTable<NewTabPageUserScript>.weakObjects()

    var userScripts: [any SubfeatureWithExternalMessageHandling] {
        userScriptsHandles.allObjects
    }

    convenience init(
        appearancePreferences: AppearancePreferences,
        activeRemoteMessageModel: ActiveRemoteMessageModel,
        openURLHandler: @escaping (URL) -> Void
    ) {
        self.init([
            NewTabPageConfigurationClient(appearancePreferences: appearancePreferences),
            NewTabPageRMFClient(activeRemoteMessageModel: activeRemoteMessageModel, openURLHandler: openURLHandler),
            NewTabPageFavoritesClient(),
            NewTabPagePrivacyStatsClient()
        ])
    }

    init(_ clients: [NewTabPageScriptClient]) {
        newTabPageScriptClients = clients
        newTabPageScriptClients.forEach { $0.userScriptsSource = self }
    }

    func registerUserScript(_ userScript: NewTabPageUserScript) {
        userScriptsHandles.add(userScript)
        newTabPageScriptClients.forEach { $0.registerMessageHandlers(for: userScript) }
    }
}
