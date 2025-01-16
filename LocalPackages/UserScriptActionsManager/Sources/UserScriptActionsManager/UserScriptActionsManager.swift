//
//  UserScriptActionsManager.swift
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
import os.log
import UserScript
import WebKit

/**
 * This protocol extends `Subfeature` and allows to register message handlers from an external source.
 *
 * `NewTabPageUserScript` manages many different features that only share the same view
 * (HTML New Tab Page) and are otherwise independent of each other.
 *
 * Implementing this protocol in `NewTabPageUserScript` allows for having multiple objects
 * registered as handlers to handle feature-specific messages, e.g. a separate object
 * responsible for RMF, favorites, privacy stats, etc.
 */
public protocol SubfeatureWithExternalMessageHandling: AnyObject, Subfeature {
    var webView: WKWebView? { get }
    func registerMessageHandlers(_ handlers: [String: Subfeature.Handler])
}

/**
 * This protocol describes type that can provide an array of user scripts.
 *
 * It's conformed to by `NewTabPageActionsManager` (via `UserScriptActionsManaging`).
 */
public protocol UserScriptsSource: AnyObject {
    associatedtype Script: SubfeatureWithExternalMessageHandling

    var userScripts: [Script] { get }
}

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
public protocol UserScriptClient: AnyObject {
    associatedtype Script: SubfeatureWithExternalMessageHandling

    /**
     * Handle to the object that returns the list of all living `NewTabPageUserScript` instances.
     */
    var userScriptsSource: (any UserScriptsSource)? { get set }

    /**
     * This function should be implemented to add all message handlers to the provided `userScript`.
     */
    func registerMessageHandlers(for userScript: Script)
}

public extension UserScriptClient {
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

    /**
     * Convenience method to push a message with specific parameters to the user script
     * associated with the given `webView`.
     */
    func pushMessage(named method: String, params: Encodable?, to webView: WKWebView) {
        guard let userScript = userScriptsSource?.userScripts.first(where: { $0.webView === webView }) else {
            return
        }
        userScript.broker?.push(method: method, params: params, for: userScript, into: webView)
    }
}

/**
 * This protocol describes the API of `NewTabPageActionsManager`.
 */
public protocol UserScriptActionsManaging: AnyObject, UserScriptsSource {
    func registerUserScript(_ userScript: Script)
}

/**
 * This class serves as an aggregator of feature-specific `NewTabPageUserScriptClient`s.
 *
 * The browser uses 1 New Tab Page (and 1 NTP User Script) per window. In order to
 * broadcast updates to all windows that show New Tab Page, and to not duplicate the logic
 * of NTP data sources, this class keeps track of all living NTP user scripts and makes sure
 * script clients' message handlers are registered with all user scripts.
 */
open class UserScriptActionsManager<Script, ScriptClient>: UserScriptActionsManaging, UserScriptsSource where Script: SubfeatureWithExternalMessageHandling,
                                                                                                                      ScriptClient: UserScriptClient,
                                                                                                                      ScriptClient.Script == Script {
    private let userScriptClients: [ScriptClient]

    /**
     * This hash table holds weak references to user scripts,
     * ensuring that no user script belonging to a closed window is ever contained within.
     */
    private let userScriptsHandles = NSHashTable<Script>.weakObjects()

    public var userScripts: [Script] {
        userScriptsHandles.allObjects
    }

    /**
     * Records user script reference internally and register all clients' message handlers
     * with the user script.
     */
    public func registerUserScript(_ userScript: Script) {
        userScriptsHandles.add(userScript)
        userScriptClients.forEach { $0.registerMessageHandlers(for: userScript) }
    }

    public init(scriptClients: [ScriptClient]) {
        userScriptClients = scriptClients
        userScriptClients.forEach { $0.userScriptsSource = self }
    }
}
