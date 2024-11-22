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
    /**
     * Convenience method to push a message with specific parameters to all user scripts
     * currently registered with `userScriptsSource`.
     */
    func pushMessage(named method: String, params: Encodable?) {
        userScriptsSource?.userScripts.forEach { userScript in
            guard let webView = userScript.webView else {
                return
            }
            userScript.broker?.push(method: method, params: params, for: userScript, into: webView)
        }
    }
}

/**
 * This protocol describes type that can provide a list of user scripts.
 *
 * It's conformed to by `NewTabPageActionsManager` (via `NewTabPageActionsManaging`).
 */
protocol NewTabPageUserScriptsSource: AnyObject {
    var userScripts: [NewTabPageUserScript] { get }
}

/**
 * This protocol describes the API of `NewTabPageActionsManager`.
 */
protocol NewTabPageActionsManaging: AnyObject, NewTabPageUserScriptsSource {
    func registerUserScript(_ userScript: NewTabPageUserScript)
}

/**
 * This class serves as an aggregator of feature-specific `NewTabPageUserScriptClient`s.
 *
 * The browser uses 1 New Tab Page (and 1 NTP User Script) per window. In order to
 * broadcast updates to all windows that show New Tab Page, and to not duplicate the logic
 * of NTP data sources, this class keeps track of all living NTP user scripts and makes sure
 * script clients' message handlers are registered with all user scripts.
 */
final class NewTabPageActionsManager: NewTabPageActionsManaging, NewTabPageUserScriptsSource {

    private let newTabPageScriptClients: [NewTabPageScriptClient]

    /**
     * This hash table holds weak references to user scripts,
     * ensuring that no user script belonging to a closed window is ever contained within.
     */
    private let userScriptsHandles = NSHashTable<NewTabPageUserScript>.weakObjects()

    var userScripts: [NewTabPageUserScript] {
        userScriptsHandles.allObjects
    }

    /**
     * Records user script reference internally and register all clients' message handlers
     * with the user script.
     */
    func registerUserScript(_ userScript: NewTabPageUserScript) {
        userScriptsHandles.add(userScript)
        newTabPageScriptClients.forEach { $0.registerMessageHandlers(for: userScript) }
    }

    init(scriptClients: [NewTabPageScriptClient]) {
        newTabPageScriptClients = scriptClients
        newTabPageScriptClients.forEach { $0.userScriptsSource = self }
    }
}

extension NewTabPageActionsManager {

    convenience init(
        appearancePreferences: AppearancePreferences,
        activeRemoteMessageModel: ActiveRemoteMessageModel,
        openURLHandler: @escaping (URL) -> Void
    ) {
        self.init(scriptClients: [
            NewTabPageConfigurationClient(appearancePreferences: appearancePreferences),
            NewTabPageRMFClient(remoteMessageProvider: activeRemoteMessageModel, openURLHandler: openURLHandler),
            NewTabPageFavoritesClient(favoritesModel: NewTabPageFavoritesModel()),
            NewTabPagePrivacyStatsClient()
        ])
    }
}
