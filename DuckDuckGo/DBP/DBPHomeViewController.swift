//
//  DBPHomeViewController.swift
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
import DataBrokerProtection
import BrowserServicesKit
import AppKit

final class DBPHomeViewController: NSViewController {
    private var scheduler: DataBrokerProtectionScheduler?


    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let button1 = NSButton(title: "Start Scan", target: self, action: #selector(scanButtonClicked(_:)))
        button1.frame = NSRect(x: 50, y: 50, width: 200, height: 30)
        view.addSubview(button1)

        let button2 = NSButton(title: "Start Scheduler", target: self, action: #selector(schedulerButtonClicked(_:)))
        button2.frame = NSRect(x: 50, y: 100, width: 200, height: 30)
        view.addSubview(button2)

        setupScheduler()
    }

    @objc func scanButtonClicked(_ sender: NSButton) {
        scheduler?.scanAllBrokers()
    }

    @objc func schedulerButtonClicked(_ sender: NSButton) {
        scheduler?.start()
    }

    private func setupScheduler() {
        let privacyConfigurationManager = PrivacyFeatures.contentBlocking.privacyConfigurationManager
        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false)

        let privacySettings = PrivacySecurityPreferences.shared
        let sessionKey = UUID().uuidString
        let prefs = ContentScopeProperties.init(gpcEnabled: privacySettings.gpcEnabled,
                                                sessionKey: sessionKey,
                                                featureToggles: features)

        scheduler = DataBrokerProtectionScheduler(privacyConfigManager: privacyConfigurationManager,
                                                      contentScopeProperties: prefs)
    }
}
