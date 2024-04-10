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

#if DBP

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

        let isGPCEnabled = WebTrackingProtectionPreferences.shared.isGPCEnabled
        let sessionKey = UUID().uuidString
        let prefs = ContentScopeProperties(gpcEnabled: isGPCEnabled,
                                           sessionKey: sessionKey,
                                           featureToggles: features)

        return DataBrokerProtectionViewController(
            scheduler: dataBrokerProtectionManager.scheduler,
            dataManager: dataBrokerProtectionManager.dataManager,
            privacyConfig: privacyConfigurationManager,
            prefs: prefs,
            webUISettings: DataBrokerProtectionWebUIURLSettings(.dbp),
            openURLHandler: { url in
                WindowControllersManager.shared.show(url: url, source: .link, newTab: true)
            })
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

        do {
            if try dataBrokerProtectionManager.dataManager.fetchProfile() != nil {
                let dbpDateStore = DefaultWaitlistActivationDateStore(source: .dbp)
                dbpDateStore.updateLastActiveDate()
            }
        } catch {
            os_log("DBPHomeViewController error: viewDidLoad, error: %{public}@", log: .error, error.localizedDescription)
            pixelHandler.fire(.generalError(error: error, functionOccurredIn: "DBPHomeViewController.viewDidLoad"))
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

    // swiftlint:disable:next function_body_length
    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .error(let error, _):
                Pixel.fire(.debug(event: .pixelKitEvent(event), error: error))
            case .generalError(let error, _),
                    .secureVaultInitError(let error),
                    .secureVaultError(let error):
                // We can't use .debug directly because it modifies the pixel name and clobbers the params
                Pixel.fire(.pixelKitEvent(DebugEvent(event, error: error)))
            case .ipcServerOptOutAllBrokersCompletion(error: let error),
                    .ipcServerScanAllBrokersCompletion(error: let error),
                    .ipcServerRunQueuedOperationsCompletion(error: let error):
                // We can't use .debug directly because it modifies the pixel name and clobbers the params
                Pixel.fire(.pixelKitEvent(DebugEvent(event, error: error)))
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
                    .optOutFillForm,
                    .optOutSuccess,
                    .optOutFailure,
                    .backgroundAgentStarted,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossible,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackStartScheduler,
                    .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
                    .ipcServerRegister,
                    .ipcServerStartScheduler,
                    .ipcServerStopScheduler,
                    .ipcServerOptOutAllBrokers,
                    .ipcServerScanAllBrokers,
                    .ipcServerRunQueuedOperations,
                    .ipcServerRunAllOperations,
                    .scanSuccess,
                    .scanFailed,
                    .scanError,
                    .dataBrokerProtectionNotificationSentFirstScanComplete,
                    .dataBrokerProtectionNotificationOpenedFirstScanComplete,
                    .dataBrokerProtectionNotificationSentFirstRemoval,
                    .dataBrokerProtectionNotificationOpenedFirstRemoval,
                    .dataBrokerProtectionNotificationScheduled2WeeksCheckIn,
                    .dataBrokerProtectionNotificationOpened2WeeksCheckIn,
                    .dataBrokerProtectionNotificationSentAllRecordsRemoved,
                    .dataBrokerProtectionNotificationOpenedAllRecordsRemoved,
                    .dailyActiveUser,
                    .weeklyActiveUser,
                    .monthlyActiveUser,
                    .weeklyReportScanning,
                    .weeklyReportRemovals,
                    .scanningEventNewMatch,
                    .scanningEventReAppearance,
                    .webUILoadingFailed,
                    .webUILoadingStarted,
                    .webUILoadingSuccess:
                Pixel.fire(.pixelKitEvent(event))
            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}

#endif
