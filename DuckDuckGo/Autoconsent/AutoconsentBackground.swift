//
//  AutoconsentBackground.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import WebKit
import os
import BrowserServicesKit

protocol AutoconsentManagement {
    func clearCache()
}

/// Central controller of autoconsent rules. Used by AutoconsentUserScript to query autoconsent rules
/// and coordinate their execution on tabs.
@available(macOS 11, *)
final class AutoconsentBackground: NSObject, WKScriptMessageHandlerWithReply, AutoconsentManagement {

    enum Constants {
        static let tabMessageName = "browserTabsMessage"
        static let actionCallbackName = "actionResponse"
        static let readyMessageName = "ready"
    }
    
    var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    var forMainFrameOnly: Bool { true }
    let source: String = {
        AutoconsentUserScript.loadJS("browser-shim", from: .main)
    }()

    @MainActor
    private var tabs = [Int: TabFrameTracker]()
    @MainActor
    private var messageCounter = 1
    @MainActor
    private var actionCallbacks = [Int: (Result<ActionResponse, Error>) -> Void]()
    @MainActor
    private var ready = false
    @MainActor
    private var readyCallbacks: [() async -> Void] = []

    @MainActor
    let background: WKWebView

    var sitesNotifiedCache = Set<String>()
    
    override init() {
        let configuration = WKWebViewConfiguration()
        background = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        // configure background webview for two-way messaging.
        configuration.userContentController.addUserScript(WKUserScript(source: source,
                                              injectionTime: injectionTime, forMainFrameOnly: true, in: .page))
        configuration.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: Constants.tabMessageName)
        configuration.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: Constants.actionCallbackName)
        configuration.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: Constants.readyMessageName)
        let url = Bundle.main.url(forResource: "autoconsent", withExtension: "html")!
        background.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    @MainActor
    func ready(onReady: @escaping () async -> Void) {
        if ready {
            Task {
                await onReady()
            }
            
        } else {
            readyCallbacks.append(onReady)
        }
    }
    
    /// Runs an action on the autoconsent background page. This action can be one of:
    ///  - `detectCMP`: Check if there is a known CMP (Consent Management Platform) present on the page.
    ///  - `detectPopup`: If there is a CMP, check if they are showing the user a popup.
    ///  - `doOptOut`: Execute a series of clicks in the page to dismiss the popup and opt the user out of all configurable options.
    ///  - `selfTest`: If implemented for thie CMP, read back the consent state to check that the opt out was successful.
    ///
    /// The result of the action is provided in an async callback.
    @MainActor func callAction(in tabId: Int, action: Action, resultCallback: @escaping (Result<ActionResponse, Error>) -> Void) {
        // create a unique message ID so we can retrieve the callback when a response comes from the background page
        let callbackId = messageCounter
        messageCounter += 1
        self.actionCallbacks[callbackId] = resultCallback
        background.evaluateJavaScript("window.callAction(\(callbackId), \(tabId), '\(action)')", in: nil, in: .page, completionHandler: { (result) in
            switch result {
            case .success:
                break
            case .failure(let error):
                self.actionCallbacks[callbackId] = nil
                resultCallback(.failure(error))
            }
        })
    }
    
    /// Async version of callAction
    @MainActor func callActionAsync(in tabId: Int, action: Action) async throws -> ActionResponse {
        return try await withCheckedThrowingContinuation { continuation in
            self.callAction(in: tabId, action: action, resultCallback: {result in
                continuation.resume(with: result)
            })
        }
    }
    
    func detectCmp(in tabId: Int) async -> ActionResponse? {
        do {
            return try await callActionAsync(in: tabId, action: .detectCMP)
        } catch {
            return nil
        }
    }
    
    func isPopupOpen(in tabId: Int) async -> Bool {
        do {
            let response = try await callActionAsync(in: tabId, action: .detectPopup)
            return response.result
        } catch {
            return false
        }
    }
    
    func doOptOut(in tabId: Int) async -> Bool {
        do {
            let response = try await callActionAsync(in: tabId, action: .doOptOut)
            return response.result
        } catch {
            return false
        }
    }
    
    func testOptOutWorked(in tabId: Int) async throws -> ActionResponse {
        return try await callActionAsync(in: tabId, action: .selfTest)
    }
    
    /// Process a message sent from the autoconsent userscript.
    @MainActor
    func onUserScriptMessage(in tabId: Int, _ message: WKScriptMessage) {
        let webview = message.webView
        let frame = message.frameInfo
        var frameId = frame.hashValue
        let ref = tabs[tabId] ?? TabFrameTracker()
        
        if frame.isMainFrame {
            frameId = 0
        }
        
        ref.webview = webview
        ref.frames[frameId] = frame
        
        // check for tabs which have been gced (i.e. the weak reference is now nil). These can be cleaned up both here and in the background page.
        for (id, tab) in tabs where tab.webview == nil {
            tabs[id] = nil
            // delete entry in background script
            background.evaluateJavaScript("window.autoconsent.removeTab(\(id));")
        }
        tabs[tabId] = ref
        
        let script = "_nativeMessageHandler(\(tabId), \(frameId), \(message.body));"
        return background.evaluateJavaScript(script)
    }

    @MainActor
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        if message.name == Constants.tabMessageName {
            // This is a message sent from the background to a specific tab and frame. We have to find the correct WKWebview and FrameInfo
            // instances in order to push the message to the Userscript.
            guard let jsonMessage = message.body as? String else {
                replyHandler(false, "data decoding error")
                return
            }
            forwardMessageToTab(message: jsonMessage, replyHandler: replyHandler)
        } else if message.name == Constants.actionCallbackName {
            // This is a message response to a call to #callAction.
            guard let jsonMessage = message.body as? String,
                  let response = try? JSONDecoder().decode(ActionResponse.self, from: Data(jsonMessage.utf8)),
                  let callback = actionCallbacks[response.messageId] else {
                replyHandler(nil, "Failed to parse message")
                return
            }
            actionCallbacks[response.messageId] = nil
            if response.error != nil {
                os_log("Action error: %s", log: .autoconsent, type: .error, String(describing: response.error))
                callback(.failure(BackgroundError.actionError))
            } else {
                callback(.success(response))
            }
            replyHandler("OK", nil)
        } else if message.name == Constants.readyMessageName {
            ready = true
            self.readyCallbacks.forEach({ cb in Task { await cb() } })
            self.readyCallbacks.removeAll()
            replyHandler("OK", nil)
        }
    }

    @MainActor
    func forwardMessageToTab(message jsonMessage: String, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let payload = try? JSONDecoder().decode(BrowserTabMessage.self, from: Data(jsonMessage.utf8)) else {
            replyHandler(false, "data decoding error")
            return
        }
        let ref = tabs[payload.tabId]
        guard let webview = ref?.webview, let frame = ref?.frames[payload.frameId] else {
            replyHandler(false, "missing frame target")
            return
        }
        var world: WKContentWorld = .defaultClient
        var script = "window.autoconsent(\(jsonMessage))"
        // Special case: for eval just run the script in page scope.
        if payload.message.type == "eval" {
            world = .page
            script = """
(() => {
try {
    return !!(\(payload.message.script ?? "{}"))
} catch (e) {}
})();
"""
        }
    
        webview.evaluateJavaScript(script, in: frame, in: world, completionHandler: { (result) in
            switch result {
            case.failure(let error):
                replyHandler(nil, "Error running \"\(script)\": \(error)")
            case.success(let value):
                replyHandler(value, nil)
            }
        })
    }
    
    @MainActor
    func updateSettings(settings: [String: Any]?) {
        let encoder = JSONEncoder()
        guard let disabledCMPs = settings?["disabledCMPs"] as? [String],
              let data = try? encoder.encode(disabledCMPs),
              let cmpList = String(data: data, encoding: .utf8) else {
            return
        }
        background.evaluateJavaScript("window.autoconsent.disableCMPs(\(cmpList));")
    }

    func clearCache() {
        dispatchPrecondition(condition: .onQueue(.main))
        sitesNotifiedCache.removeAll()
    }
    
    final class TabFrameTracker {
        weak var webview: WKWebView?
        var frames = [Int: WKFrameInfo]()
    }

    struct BrowserTabMessage: Codable {
        var messageId: Int
        var tabId: Int
        var frameId: Int
        var message: ContentScriptMessage
    }

    struct ContentScriptMessage: Codable {
        var type: String
        var script: String?
        var selectors: [String]?
    }

    struct ActionResponse: Codable {
        var messageId: Int
        var ruleName: String?
        var result: Bool
        var error: String?
    }

    enum BackgroundError: Error {
        case invalidResponse
        case actionError
    }

    enum Action {
        case detectCMP
        case detectPopup
        case doOptOut
        case selfTest
        case prehide
        case unhide
    }

}
