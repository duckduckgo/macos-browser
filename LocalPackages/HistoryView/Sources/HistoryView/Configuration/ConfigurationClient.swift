//
//  ConfigurationClient.swift
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

import AppKit
import Combine
import Common
import os.log
import UserScriptActionsManager
import WebKit

public final class ConfigurationClient: HistoryViewUserScriptClient {

    private var cancellables = Set<AnyCancellable>()

    public override init() {
        super.init()
    }

    enum MessageName: String, CaseIterable {
        case initialSetup
        case reportInitException
        case reportPageException
    }

    public override func registerMessageHandlers(for userScript: HistoryViewUserScript) {
        userScript.registerMessageHandlers([
            MessageName.initialSetup.rawValue: { [weak self] in try await self?.initialSetup(params: $0, original: $1) },
            MessageName.reportInitException.rawValue: { [weak self] in try await self?.reportException(params: $0, original: $1) },
            MessageName.reportPageException.rawValue: { [weak self] in try await self?.reportException(params: $0, original: $1) },
        ])
    }

    @MainActor
    private func initialSetup(params: Any, original: WKScriptMessage) async throws -> Encodable? {
#if DEBUG || REVIEW
        let env = "development"
#else
        let env = "production"
#endif

        let config = DataModel.Configuration(
            env: env,
            locale: Bundle.main.preferredLocalizations.first ?? "en",
            platform: .init(name: "macos")
        )
        return config
    }

    private func reportException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let params = params as? [String: String] else { return nil }
        let message = params["message"] ?? ""
        let id = params["id"] ?? ""
        Logger.general.error("New Tab Page error: \("\(id): \(message)", privacy: .public)")
        return nil
    }
}
