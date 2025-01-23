//
//  UserScriptActionsManager.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
 * If a user script handles many different features that share the same view
 * and are otherwise independent of each other, it can implement this protocol
 * to allow for having multiple objects registered as handlers to handle
 * feature-specific messages.
 *
 * An example of this is HTML New Tab Page, where `NewTabPageUserScript` uses
 * separate classes to handle feature-specific messages, e.g. a separate object
 * responsible for RMF, favorites, privacy stats, etc.
 */
public protocol SubfeatureWithExternalMessageHandling: AnyObject, Subfeature {

    /**
     * A handle to the webView the user script is loaded into.
     */
    var webView: WKWebView? { get }

    /**
     * This function should register message handlers provided in the `handlers` array
     * to handle messages
     */
    func registerMessageHandlers(_ handlers: [String: Subfeature.Handler])
}

/**
 * This protocol describes a feature or a set of features that use the user script and handle its messages.
 *
 * A class implementing this protocol can register handlers for a subset of
 * `Script`'s messages, allowing for better separation of concerns.
 *
 * `UserScriptClient` supports being connected to multiple user scripts (of the same type),
 * in case one data source should control multiple script instances (in multiple webViews).
 *
 * Objects implementing this protocol, together with user script instances,
 * are kept in `UserScriptActionsManager`.
 */
public protocol UserScriptClient: AnyObject {
    associatedtype Script: SubfeatureWithExternalMessageHandling

    /**
     * Handle to the actions manager, that contains the list of all living user script instances.
     */
    var actionsManager: (any UserScriptActionsManaging)? { get set }

    /**
     * This function should be implemented to add all message handlers to the provided `userScript`.
     */
    func registerMessageHandlers(for userScript: Script)
}

public extension UserScriptClient {
    /**
     * Convenience method to push a message with specific parameters to all user scripts
     * currently registered with the `actionsManager`.
     */
    func pushMessage(named method: String, params: Encodable?) {
        actionsManager?.userScripts.forEach { userScript in
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
        guard let userScript = actionsManager?.userScripts.first(where: { $0.webView === webView }) else {
            return
        }
        userScript.broker?.push(method: method, params: params, for: userScript, into: webView)
    }
}

/**
 * This protocol defines API to aggregate user scripts of the same type.
 */
public protocol UserScriptActionsManaging: AnyObject {
    associatedtype Script: SubfeatureWithExternalMessageHandling

    var userScripts: [Script] { get }

    /**
     * Allows to register a user script with the actions manager.
     */
    func registerUserScript(_ userScript: Script)
}

/**
 * This class serves as an aggregator of instances of a specific user script and
 * that user script's feature-specific clients.
 *
 * This class helps orchestrate messaging between native data source and multiple
 * user script instances (in multiple web views) that need to stay in sync. It keeps
 * track of all living user scripts and makes user script clients' message handlers are
 * registered with all user scripts.
 *
 * The example usage of UserScriptActionsManager is HTML New Tab Page. The browser uses
 * 1 New Tab Page (and 1 NTP User Script) per window. Using actions manager allows to
 * broadcast updates to all windows that show New Tab Page, and to not duplicate the logic
 * of NTP data sources.
 */
open class UserScriptActionsManager<Script, ScriptClient>: UserScriptActionsManaging where Script: SubfeatureWithExternalMessageHandling,
                                                                                           ScriptClient: UserScriptClient,
                                                                                           ScriptClient.Script == Script {

    public init(scriptClients: [ScriptClient]) {
        userScriptClients = scriptClients
        userScriptClients.forEach { $0.actionsManager = self }
    }

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

    /**
     * This hash table holds weak references to user scripts,
     * ensuring that no user script belonging to a closed window is ever contained within.
     */
    private let userScriptsHandles = NSHashTable<Script>.weakObjects()
    private let userScriptClients: [ScriptClient]
}
