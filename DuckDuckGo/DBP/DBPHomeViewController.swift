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


public extension Notification.Name {
    static let dbpDidClose = Notification.Name("com.duckduckgo.DBP.DBPDidClose")
}

final class DBPHomeViewController: NSViewController {
    private var presentedWindowController: NSWindowController?
    private let dataBrokerProtectionManager: DataBrokerProtectionManager

    lazy var dataBrokerProtectionViewController: DataBrokerProtectionViewController = {
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

        return DataBrokerProtectionViewController(
            scheduler: dataBrokerProtectionManager.scheduler,
            dataManager: dataBrokerProtectionManager.dataManager,
            notificationCenter: NotificationCenter.default,
            privacyConfig: privacyConfigurationManager,
            prefs: prefs)
    }()

    init(dataBrokerProtectionManager: DataBrokerProtectionManager) {
        self.dataBrokerProtectionManager = dataBrokerProtectionManager
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

        if !dataBrokerProtectionManager.shouldAskForInviteCode() {
            attachDataBrokerContainerView()
        }
    }

    private func attachDataBrokerContainerView() {
        addChild(dataBrokerProtectionViewController)
        view.addSubview(dataBrokerProtectionViewController.view)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if dataBrokerProtectionManager.shouldAskForInviteCode() {
            presentInviteCodeFlow()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        dataBrokerProtectionViewController.view.frame = view.bounds
    }

    private func presentInviteCodeFlow() {
        let viewModel = DataBrokerProtectionInviteDialogsViewModel(delegate: self)

        let view = DataBrokerProtectionInviteDialogsView(viewModel: viewModel)
        let hostingVC = NSHostingController(rootView: view)
        presentedWindowController = hostingVC.wrappedInWindowController()

        guard let newWindow = presentedWindowController?.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Failed to present \(hostingVC)")
            return
        }
        parentWindowController.window?.beginSheet(newWindow)
    }
}

extension DBPHomeViewController: DataBrokerProtectionInviteDialogsViewModelDelegate {
    func dataBrokerProtectionInviteDialogsViewModelDidReedemSuccessfully(_ viewModel: DataBrokerProtectionInviteDialogsViewModel) {
        presentedWindowController?.window?.close()
        presentedWindowController = nil
        attachDataBrokerContainerView()
    }

    func dataBrokerProtectionInviteDialogsViewModelDidCancel(_ viewModel: DataBrokerProtectionInviteDialogsViewModel) {
        presentedWindowController?.window?.close()
        presentedWindowController = nil
        NotificationCenter.default.post(name: .dbpDidClose, object: nil)
    }
}

public class DataBrokerProtectionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {

    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .error(let error, _):
                Pixel.fire(.debug(event: .pixelKitEvent(event), error: error))
            case .parentChildMatches,
                    .optOutStart,
                    .optOutEmailGenerate,
                    .optOutCaptchaParse,
                    .optOutCaptchaSend,
                    .optOutCaptchaSolve,
                    .optOutSubmit,
                    .optOutEmailReceive,
                    .optOutEmailConfirm,
                    .optOutValidate,
                    .optOutFinish,
                    .optOutSubmitSuccess,
                    .optOutSuccess,
                    .optOutFailure:
                Pixel.fire(.pixelKitEvent(event))
            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}
