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

        return DataBrokerProtectionViewController(scheduler: dataBrokerProtectionManager.scheduler,
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

    // swiftlint:disable:next cyclomatic_complexity
    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .error(let error, _):
                Pixel.fire(.debug(event: .dataBrokerProtectionError, error: error), withAdditionalParameters: event.params)
            case .optOutStart:
                Pixel.fire(.debug(event: .optOutStart), withAdditionalParameters: event.params)
            case .optOutEmailGenerate:
                Pixel.fire(.debug(event: .optOutEmailGenerate), withAdditionalParameters: event.params)
            case .optOutCaptchaParse:
                Pixel.fire(.debug(event: .optOutCaptchaParse), withAdditionalParameters: event.params)
            case .optOutCaptchaSend:
                Pixel.fire(.debug(event: .optOutCaptchaSend), withAdditionalParameters: event.params)
            case .optOutCaptchaSolve:
                Pixel.fire(.debug(event: .optOutCaptchaSolve), withAdditionalParameters: event.params)
            case .optOutSubmit:
                Pixel.fire(.debug(event: .optOutSubmit), withAdditionalParameters: event.params)
            case .optOutEmailReceive:
                Pixel.fire(.debug(event: .optOutEmailReceive), withAdditionalParameters: event.params)
            case .optOutEmailConfirm:
                Pixel.fire(.debug(event: .optOutEmailConfirm), withAdditionalParameters: event.params)
            case .optOutValidate:
                Pixel.fire(.debug(event: .optOutValidate), withAdditionalParameters: event.params)
            case .optOutFinish:
                Pixel.fire(.debug(event: .optOutFinish), withAdditionalParameters: event.params)
            case .optOutSuccess:
                Pixel.fire(.debug(event: .optOutSuccess), withAdditionalParameters: event.params)
            case .optOutFailure:
                Pixel.fire(.debug(event: .optOutFailure), withAdditionalParameters: event.params)
            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}
