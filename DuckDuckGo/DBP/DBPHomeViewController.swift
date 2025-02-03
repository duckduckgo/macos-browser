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
import AppKit
import Common
import SwiftUI
import BrowserServicesKit
import PixelKit

public extension Notification.Name {
    static let dbpDidClose = Notification.Name("com.duckduckgo.DBP.DBPDidClose")
}

final class DBPHomeViewController: NSViewController {
    private var presentedWindowController: NSWindowController?
    private let dataBrokerProtectionManager: DataBrokerProtectionManager
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler()
    private var currentChildViewController: NSViewController?
    private var observer: NSObjectProtocol?
    private var freemiumDBPFeature: FreemiumDBPFeature

    private let prerequisiteVerifier: DataBrokerPrerequisitesStatusVerifier
    private lazy var errorViewController: DataBrokerProtectionErrorViewController = {
        DataBrokerProtectionErrorViewController()
    }()

    private lazy var dataBrokerProtectionViewController: DataBrokerProtectionViewController = {
        let privacyConfigurationManager = PrivacyFeatures.contentBlocking.privacyConfigurationManager
        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false,
                                                  unknownUsernameCategorization: false,
                                                  partialFormSaves: false)

        let isGPCEnabled = WebTrackingProtectionPreferences.shared.isGPCEnabled
        let sessionKey = UUID().uuidString
        let messageSecret = UUID().uuidString
        let prefs = ContentScopeProperties(gpcEnabled: isGPCEnabled,
                                           sessionKey: sessionKey,
                                           messageSecret: messageSecret,
                                           featureToggles: features)

        return DataBrokerProtectionViewController(
            agentInterface: dataBrokerProtectionManager.loginItemInterface,
            dataManager: dataBrokerProtectionManager.dataManager,
            privacyConfig: privacyConfigurationManager,
            prefs: prefs,
            webUISettings: DataBrokerProtectionWebUIURLSettings(.dbp),
            openURLHandler: { url in
                WindowControllersManager.shared.show(url: url, source: .link, newTab: true)
            })
    }()

    init(dataBrokerProtectionManager: DataBrokerProtectionManager,
         prerequisiteVerifier: DataBrokerPrerequisitesStatusVerifier = DefaultDataBrokerPrerequisitesStatusVerifier(),
         freemiumDBPFeature: FreemiumDBPFeature) {
        self.dataBrokerProtectionManager = dataBrokerProtectionManager
        self.prerequisiteVerifier = prerequisiteVerifier
        self.freemiumDBPFeature = freemiumDBPFeature
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

        setupUI()
        setupObserver()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if !dataBrokerProtectionManager.isUserAuthenticated() && !freemiumDBPFeature.isAvailable {
            assertionFailure("This UI should never be presented if the user is not authenticated")
            closeUI()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if let currentChildViewController = currentChildViewController {
            currentChildViewController.view.frame = view.bounds
        }
    }

    private func setupUI() {
        setupUIWithCurrentStatus()
    }

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.setupUI()
        }
    }

    private func setupUIWithCurrentStatus() {
        setupUIWithStatus(prerequisiteVerifier.checkStatus())
    }

    private func setupUIWithStatus(_ status: DataBrokerPrerequisitesStatus) {
        switch status {
        case .invalidDirectory:
            displayWrongDirectoryErrorUI()
            pixelHandler.fire(.homeViewShowBadPathError)
        case .invalidSystemPermission:
            displayWrongPermissionsErrorUI()
            pixelHandler.fire(.homeViewShowNoPermissionError)
        case .valid:
            displayDBPUI()
            pixelHandler.fire(.homeViewShowWebUI)
        }
    }

    private func displayDBPUI() {
        replaceChildController(dataBrokerProtectionViewController)
    }

    private func replaceChildController(_ childViewController: NSViewController) {
        if let child = currentChildViewController {
            child.removeCompletely()
        }

        addAndLayoutChild(childViewController)
        self.currentChildViewController = childViewController
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func closeUI() {
        presentedWindowController?.window?.close()
        presentedWindowController = nil
        NotificationCenter.default.post(name: .dbpDidClose, object: nil)
    }
}

// MARK: - Error UI

extension DBPHomeViewController {
    private func displayWrongDirectoryErrorUI() {
        let errorViewModel = DataBrokerProtectionErrorViewModel(title: UserText.dbpErrorPageBadPathTitle,
                                                                message: UserText.dbpErrorPageBadPathMessage,
                                                                ctaText: UserText.dbpErrorPageBadPathCTA,
                                                                ctaAction: { [weak self] in
            self?.moveToApplicationFolder()
        })

        errorViewController.errorViewModel = errorViewModel
        replaceChildController(errorViewController)
    }

    private func displayWrongPermissionsErrorUI() {
        let errorViewModel = DataBrokerProtectionErrorViewModel(title: UserText.dbpErrorPageNoPermissionTitle,
                                                                message: UserText.dbpErrorPageNoPermissionMessage,
                                                                ctaText: UserText.dbpErrorPageNoPermissionCTA,
                                                                ctaAction: { [weak self] in
            self?.openLoginItemSettings()
        })

        errorViewController.errorViewModel = errorViewModel
        replaceChildController(errorViewController)
    }
}

// MARK: - System configuration

import AppLauncher
import ServiceManagement
import VPNAppLauncher

extension DBPHomeViewController {
    func openLoginItemSettings() {
        pixelHandler.fire(.homeViewCTAGrantPermissionClicked)
        if #available(macOS 13.0, *) {
            SMAppService.openSystemSettingsLoginItems()
        } else {
            let loginItemsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
            NSWorkspace.shared.open(loginItemsURL)
        }
    }

    func moveToApplicationFolder() {
        pixelHandler.fire(.homeViewCTAMoveApplicationClicked)
        Task { @MainActor in
            try? await AppLauncher(appBundleURL: Bundle.main.bundleURL).launchApp(withCommand: VPNAppLaunchCommand.moveAppToApplications)
        }
    }
}
