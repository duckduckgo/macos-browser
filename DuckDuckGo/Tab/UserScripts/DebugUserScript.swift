//
//  DebugUserScript.swift
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
import UserScript
import os.log

protocol TabInstrumentationProtocol: AnyObject {
    func request(url: String, allowedIn timeInMs: Double)
    func tracker(url: String, allowedIn timeInMs: Double, reason: String?)
    func tracker(url: String, blockedIn timeInMs: Double)
    func jsEvent(name: String, executedIn timeInMs: Double)
}

final class DebugUserScript: NSObject, StaticUserScript {

    enum MessageNames: String, CaseIterable {

        case signpost
        case log

    }

    static var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    static var forMainFrameOnly: Bool { false }
    var messageNames: [String] { MessageNames.allCases.map(\.rawValue) }
    @MainActor
    static let source: String = {
        #if DEBUG
            return DebugUserScript.debugMessagingEnabledSource
        #else
            return DebugUserScript.debugMessagingDisabledSource
        #endif
    }()
    static var script: WKUserScript = DebugUserScript.makeWKUserScript()

    weak var instrumentation: TabInstrumentationProtocol?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let messageType = MessageNames(rawValue: message.name)

        switch messageType {

        case .signpost:
            handleSignpost(message: message)

        case .log:
            handleLog(message: message)

        default: break
        }
    }

    private func handleLog(message: WKScriptMessage) {
        // Used to log JS debug events. This is noisy every time a new tab is opened, so it's commented out unless needed.
//        Logger.general.debug("Handle log \(String(describing: message.body))")
    }

    private func handleSignpost(message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
        let event = dict["event"] as? String else { return }

        if event == "Request Allowed" {
            if let elapsedTimeInMs = dict["time"] as? Double,
                let url = dict["url"] as? String {
                instrumentation?.request(url: url, allowedIn: elapsedTimeInMs)
            }
        } else if event == "Tracker Allowed" {
            if let elapsedTimeInMs = dict["time"] as? Double,
                let url = dict["url"] as? String,
                let reason = dict["reason"] as? String? {
                instrumentation?.tracker(url: url, allowedIn: elapsedTimeInMs, reason: reason)
            }
        } else if event == "Tracker Blocked" {
            if let elapsedTimeInMs = dict["time"] as? Double,
                let url = dict["url"] as? String {
                instrumentation?.tracker(url: url, blockedIn: elapsedTimeInMs)
            }
        } else if event == "Generic" {
            if let name = dict["name"] as? String,
                let elapsedTimeInMs = dict["time"] as? Double {
                instrumentation?.jsEvent(name: name, executedIn: elapsedTimeInMs)
            }
        }
    }
}

extension DebugUserScript {

    static let debugMessagingEnabledSource = """
var duckduckgoDebugMessaging = function() {

    function signpostEvent(data) {
        try {
            webkit.messageHandlers.signpostMessage.postMessage(data);
        } catch(error) {}
    }

    function log() {
        try {
            webkit.messageHandlers.log.postMessage(JSON.stringify(arguments));
        } catch(error) {}
    }

    return {
        signpostEvent: signpostEvent,
        log: log
    }
}()
"""

    static let debugMessagingDisabledSource = """
var duckduckgoDebugMessaging = function() {

    function signpostEvent(data) {}

    function log() {}

    return {
        signpostEvent: signpostEvent,
        log: log
    }
}()
"""

}
