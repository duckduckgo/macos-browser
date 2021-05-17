//
//  ContentBlockerUserScript.swift
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

protocol ContentBlockerUserScriptDelegate: AnyObject {

    func contentBlockerUserScriptShouldProcessTrackers(_ script: UserScript) -> Bool
    func contentBlockerUserScript(_ script: ContentBlockerUserScript, detectedTracker tracker: DetectedTracker, withSurrogate host: String)
    func contentBlockerUserScript(_ script: UserScript, detectedTracker tracker: DetectedTracker)

}

final class ContentBlockerUserScript: NSObject, UserScript {

    struct TrackerDetectedKey {
        static let protectionId = "protectionId"
        static let blocked = "blocked"
        static let networkName = "networkName"
        static let url = "url"
        static let isSurrogate = "isSurrogate"
    }

    var injectionTime: WKUserScriptInjectionTime { .atDocumentStart }
    var forMainFrameOnly: Bool { false }
    var messageNames: [String] { ["trackerDetectedMessage"] }
    let source: String

    init(scriptSource: ScriptSourceProviding = DefaultScriptSourceProvider.shared) {
        source = scriptSource.contentBlockerSource
    }

    weak var delegate: ContentBlockerUserScriptDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let delegate = delegate else { return }
        guard delegate.contentBlockerUserScriptShouldProcessTrackers(self) else { return }

        guard let dict = message.body as? [String: Any] else { return }
        guard let blocked = dict[TrackerDetectedKey.blocked] as? Bool else { return }
        guard let urlString = dict[TrackerDetectedKey.url] as? String else { return }

        let tracker = trackerFromUrl(urlString.trimmingWhitespaces(), blocked)

        if let isSurrogate = dict[TrackerDetectedKey.isSurrogate] as? Bool, isSurrogate, let host = URL(string: urlString)?.host {
            delegate.contentBlockerUserScript(self, detectedTracker: tracker, withSurrogate: host)
        } else {
            delegate.contentBlockerUserScript(self, detectedTracker: tracker)
        }
    }

    private func trackerFromUrl(_ urlString: String, _ blocked: Bool) -> DetectedTracker {
        let knownTracker = TrackerRadarManager.shared.findTracker(forUrl: urlString)
        let entity = TrackerRadarManager.shared.findEntity(byName: knownTracker?.owner?.name ?? "")
        return DetectedTracker(url: urlString, knownTracker: knownTracker, entity: entity, blocked: blocked)
    }

}
