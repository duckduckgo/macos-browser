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
import Common
import SwiftUI

final class DBPHomeViewController: NSViewController {
    private var scheduler: DataBrokerProtectionScheduler?
    lazy var userProfileViewController: DataBrokerUserProfileViewController = {
        DataBrokerUserProfileViewController(dataManager: dataManager)
    }()

    lazy var profileQueryViewController: DataBrokerProfileQueryViewController = {
        DataBrokerProfileQueryViewController(dataManager: dataManager)
    }()

    var startSchedulerButton: NSButton!
    var startScanButton: NSButton!
    var resetDataButton: NSButton!
    private let dataManager = DataBrokerProtectionDataManager()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScheduler()

        addChild(userProfileViewController)
        view.addSubview(userProfileViewController.view)

        addChild(profileQueryViewController)
        view.addSubview(profileQueryViewController.view)

        startSchedulerButton = NSButton(title: "Start Scheduler", target: self, action: #selector(startSchedulerButtonPressed))

        startScanButton = NSButton(title: "Start Scan", target: self, action: #selector(startScanButtonPressed))

        resetDataButton = NSButton(title: "Reset All Data", target: self, action: #selector(resetDataButtonPressed))

        view.addSubview(startSchedulerButton)
        view.addSubview(startScanButton)
        view.addSubview(resetDataButton)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        profileQueryViewController.view.frame = CGRect(x: 0, y: 0, width: view.bounds.width * 0.6, height: view.bounds.height)
        profileQueryViewController.view.autoresizingMask = [.width, .height]

        userProfileViewController.view.frame = CGRect(x: profileQueryViewController.view.frame.width, y: 0, width: view.bounds.width * 0.4, height: view.bounds.height)
        userProfileViewController.view.autoresizingMask = [.width, .height]

        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 30
        let spacing: CGFloat = 10
        let buttonY = view.bounds.height - CGFloat(3) * (buttonHeight + spacing)

        startSchedulerButton.frame = CGRect(x: view.bounds.width - buttonWidth - spacing, y: buttonY, width: buttonWidth, height: buttonHeight)

        startScanButton.frame = CGRect(x: view.bounds.width - buttonWidth - spacing, y: buttonY + buttonHeight + spacing, width: buttonWidth, height: buttonHeight)

        resetDataButton.frame = CGRect(x: view.bounds.width - buttonWidth - spacing, y: buttonY + 2 * (buttonHeight + spacing), width: buttonWidth, height: buttonHeight)
    }

    @objc func startSchedulerButtonPressed() {
        scheduler?.start()
    }

    @objc func startScanButtonPressed() {
        scheduler?.scanAllBrokers()
    }

    @objc func resetDataButtonPressed() {
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
                                                  contentScopeProperties: prefs,
                                                  dataManager: dataManager,
                                                  notificationCenter: NotificationCenter.default,
                                                  errorHandler: DataBrokerProtectionErrorHandling())
    }
}

public class DataBrokerProtectionErrorHandling: EventMapping<DataBrokerProtectionOperationError> {

    public init() {
        super.init { event, _, _, _ in
            Pixel.fire(.debug(event: .dataBrokerProtectionError, error: event.error), withAdditionalParameters: event.params)
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionOperationError>.Mapping) {
        fatalError("Use init()")
    }
}
