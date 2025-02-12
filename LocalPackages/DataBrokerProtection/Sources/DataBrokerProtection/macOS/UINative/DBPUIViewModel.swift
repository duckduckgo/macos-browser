//
//  DBPUIViewModel.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import WebKit
import BrowserServicesKit
import Common
import os.log

protocol DBPUIScanOps: AnyObject {
    func updateCacheWithCurrentScans() async
    func getBackgroundAgentMetadata() async -> DBPBackgroundAgentMetadata?
}

public final class DBPUIViewModel {
    private let dataManager: DataBrokerProtectionDataManaging
    private let agentInterface: DataBrokerProtectionAppToAgentInterface

    private let privacyConfig: PrivacyConfigurationManaging?
    private let prefs: ContentScopeProperties?
    private var communicationLayer: DBPUICommunicationLayer?
    private var webView: WKWebView?
    private let webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()

    public init(dataManager: DataBrokerProtectionDataManaging,
                agentInterface: DataBrokerProtectionAppToAgentInterface,
                webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable,
                privacyConfig: PrivacyConfigurationManaging? = nil,
                prefs: ContentScopeProperties? = nil,
                webView: WKWebView? = nil) {
        self.dataManager = dataManager
        self.agentInterface = agentInterface
        self.webUISettings = webUISettings
        self.privacyConfig = privacyConfig
        self.prefs = prefs
        self.webView = webView
    }

    @MainActor func setupCommunicationLayer() -> WKWebViewConfiguration? {
        guard let privacyConfig = privacyConfig else { return nil }
        guard let prefs = prefs else { return nil }

        let configuration = WKWebViewConfiguration()
        configuration.applyDBPUIConfiguration(privacyConfig: privacyConfig,
                                              prefs: prefs,
                                              delegate: dataManager.cache,
                                              webUISettings: webUISettings)
        dataManager.cache.scanDelegate = self
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        if let dbpUIContentController = configuration.userContentController as? DBPUIUserContentController {
            communicationLayer = dbpUIContentController.dbpUIUserScripts.dbpUICommunicationLayer
        }

        return configuration
    }
}

extension DBPUIViewModel: DBPUIScanOps {
    func profileSaved() {
        agentInterface.profileSaved()
    }

    func updateCacheWithCurrentScans() async {
        do {
            try dataManager.prepareBrokerProfileQueryDataCache()
        } catch {
            Logger.dataBrokerProtection.error("DBPUIViewModel error: updateCacheWithCurrentScans, error: \(error.localizedDescription, privacy: .public)")
            pixelHandler.fire(.databaseError(error: error, functionOccurredIn: "DBPUIViewModel.updateCacheWithCurrentScans"))
        }
    }

    func getBackgroundAgentMetadata() async -> DBPBackgroundAgentMetadata? {
        return await agentInterface.getDebugMetadata()
    }
}
