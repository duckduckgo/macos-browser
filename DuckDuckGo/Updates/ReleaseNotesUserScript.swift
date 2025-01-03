//
//  ReleaseNotesUserScript.swift
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
import UserScript
import WebKit
import Combine

#if SPARKLE

final class ReleaseNotesUserScript: NSObject, Subfeature {

    lazy var updateController: UpdateControllerProtocol = Application.appDelegate.updateController
    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [.exact(hostname: "release-notes")])
    let featureName: String = "release-notes"
    weak var broker: UserScriptMessageBroker?
    weak var webView: WKWebView? {
        didSet {
            onUpdate()
        }
    }
    private var cancellables = Set<AnyCancellable>()
    private var isInitialized = false

    // MARK: - MessageNames
    enum MessageNames: String, CaseIterable {
        case initialSetup
        case reportPageException
        case reportInitException
        case browserRestart
        case retryUpdate
    }

    override init() {
        super.init()
    }

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    private lazy var methodHandlers: [MessageNames: Handler] = [
        .initialSetup: initialSetup,
        .reportPageException: reportPageException,
        .reportInitException: reportInitException,
        .browserRestart: browserRestart,
        .retryUpdate: retryUpdate,
    ]

    @MainActor
    func handler(forMethodNamed methodName: String) -> Handler? {
        guard let messageName = MessageNames(rawValue: methodName) else { return nil }
        return methodHandlers[messageName]
    }

    public func onUpdate() {
        guard NSApp.runType != .uiTests, isInitialized, let webView = webView else {
            return
        }

        guard webView.url == .releaseNotes else {
            return
        }

        guard let updateController = Application.appDelegate.updateController else {
            return
        }

        let values = ReleaseNotesValues(from: updateController)
        broker?.push(method: "onUpdate", params: values, for: self, into: webView)
    }

    // MARK: - UserValuesNotification

    struct UserValuesNotification: Encodable {
        let userValuesNotification: UserValues
    }

}

extension ReleaseNotesUserScript {

    @MainActor
    private func initialSetup(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        isInitialized = true

        // Initialize the page right after sending the initial setup result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.onUpdate()
        }

#if DEBUG
        let env = "development"
#else
        let env = "production"
#endif

        return InitialSetupResult(env: env, locale: Locale.current.identifier)
    }

    @MainActor
    private func retryUpdate(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        DispatchQueue.main.async { [weak self] in
            self?.updateController.checkForUpdateSkippingRollout()
        }
        return nil
    }

    struct InitialSetupResult: Encodable {
        let env: String
        let locale: String
    }

    @MainActor
    private func reportPageException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return nil
    }

    @MainActor
    private func reportInitException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return nil
    }

    private func browserRestart(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        DispatchQueue.main.async { [weak self] in
            self?.updateController.runUpdate()
        }
        return nil
    }

    struct Result: Encodable {}

}

#endif
