//
//  PreferencesViewController.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import SwiftUI
import SwiftUIExtensions
import Combine
import DDGSync
import NetworkProtection

final class PreferencesViewController: NSViewController {

    weak var delegate: BrowserTabSelectionDelegate?

    let model: PreferencesSidebarModel
    let tabCollectionViewModel: TabCollectionViewModel
    let privacyConfigurationManager: PrivacyConfigurationManaging
    private var selectedTabContentCancellable: AnyCancellable?
    private var selectedPreferencePaneCancellable: AnyCancellable?

    private var bitwardenManager: BWManagement = BWManager.shared

    init(
        syncService: DDGSyncing,
        duckPlayer: DuckPlayer = DuckPlayer.shared,
        tabCollectionViewModel: TabCollectionViewModel,
        privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
        aiChatRemoteSettings: AIChatRemoteSettingsProvider = AIChatRemoteSettings()
    ) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.privacyConfigurationManager = privacyConfigurationManager
        model = PreferencesSidebarModel(syncService: syncService,
                                        vpnGatekeeper: DefaultVPNFeatureGatekeeper(subscriptionManager: Application.appDelegate.subscriptionManager),
                                        includeDuckPlayer: duckPlayer.shouldDisplayPreferencesSideBar,
                                        includeAIChat: aiChatRemoteSettings.isAIChatEnabled)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let addressBarModel = HomePage.Models.AddressBarModel(
            tabCollectionViewModel: tabCollectionViewModel,
            privacyConfigurationManager: privacyConfigurationManager
        )

        let prefRootView = Preferences.RootView(model: model,
                                                addressBarModel: addressBarModel,
                                                subscriptionManager: Application.appDelegate.subscriptionManager,
                                                subscriptionUIHandler: Application.appDelegate.subscriptionUIHandler)
        let host = NSHostingView(rootView: prefRootView)
        view.addAndLayout(host)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        model.refreshSections()
        bitwardenManager.refreshStatusIfNeeded()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        selectedTabContentCancellable = model.selectedTabContent
            .dropFirst()
            .sink { [weak self] in
                self?.delegate?.selectedTabContent($0)
            }

        selectedPreferencePaneCancellable = model.$selectedPane
            .dropFirst()
            .sink { [weak self] identifier in
                self?.delegate?.selectedPreferencePane(identifier)
            }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        selectedTabContentCancellable = nil
        selectedPreferencePaneCancellable = nil
    }
}
