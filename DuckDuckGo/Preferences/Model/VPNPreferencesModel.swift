//
//  VPNPreferencesModel.swift
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
import Combine
import Foundation
import NetworkProtection
import NetworkProtectionUI
import BrowserServicesKit

final class VPNPreferencesModel: ObservableObject {

    @Published var locationItem: VPNLocationPreferenceItemModel

    @Published var alwaysON = true

    @Published var connectOnLogin: Bool {
        didSet {
            settings.connectOnLogin = connectOnLogin
        }
    }

    @Published var excludeLocalNetworks: Bool {
        didSet {
            settings.excludeLocalNetworks = excludeLocalNetworks
        }
    }

    @Published var secureDNS: Bool = true

    @Published var showInMenuBar: Bool {
        didSet {
            settings.showInMenuBar = showInMenuBar
        }
    }

    @Published var showInBrowserToolbar: Bool {
        didSet {
            if showInBrowserToolbar {
                pinningManager.pin(.networkProtection)
            } else {
                pinningManager.unpin(.networkProtection)
            }
        }
    }

    @Published var notifyStatusChanges: Bool {
        didSet {
            settings.notifyStatusChanges = notifyStatusChanges
        }
    }

    @Published var showUninstallVPN: Bool

    private var onboardingStatus: OnboardingStatus {
        didSet {
            showUninstallVPN = DefaultVPNFeatureGatekeeper(subscriptionManager: Application.appDelegate.subscriptionManager).isInstalled
        }
    }

    private let settings: VPNSettings
    private let pinningManager: PinningManager
    private var cancellables = Set<AnyCancellable>()

    init(settings: VPNSettings = .init(defaults: .netP),
         pinningManager: PinningManager = LocalPinningManager.shared,
         defaults: UserDefaults = .netP) {
        self.settings = settings
        self.pinningManager = pinningManager

        connectOnLogin = settings.connectOnLogin
        excludeLocalNetworks = settings.excludeLocalNetworks
        notifyStatusChanges = settings.notifyStatusChanges
        showInMenuBar = settings.showInMenuBar
        showInBrowserToolbar = pinningManager.isPinned(.networkProtection)
        showUninstallVPN = defaults.networkProtectionOnboardingStatus != .default
        onboardingStatus = defaults.networkProtectionOnboardingStatus
        locationItem = VPNLocationPreferenceItemModel(selectedLocation: settings.selectedLocation)

        subscribeToOnboardingStatusChanges(defaults: defaults)
        subscribeToShowInMenuBarSettingChanges()
        subscribeToShowInBrowserToolbarSettingsChanges()
        subscribeToLocationSettingChanges()
    }

    func subscribeToOnboardingStatusChanges(defaults: UserDefaults) {
        defaults.networkProtectionOnboardingStatusPublisher
            .assign(to: \.onboardingStatus, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    func subscribeToShowInMenuBarSettingChanges() {
        settings.showInMenuBarPublisher
            .removeDuplicates()
            .assign(to: \.showInMenuBar, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    func subscribeToShowInBrowserToolbarSettingsChanges() {
        NotificationCenter.default.publisher(for: .PinnedViewsChanged).sink { [weak self] notification in
            guard let self = self else {
                return
            }

            if let userInfo = notification.userInfo as? [String: Any],
               let viewType = userInfo[LocalPinningManager.pinnedViewChangedNotificationViewTypeKey] as? String,
               let view = PinnableView(rawValue: viewType) {
                switch view {
                case .networkProtection: self.showInBrowserToolbar = self.pinningManager.isPinned(.networkProtection)
                default: break
                }
            }
        }
        .store(in: &cancellables)
    }

    func subscribeToLocationSettingChanges() {
        settings.selectedLocationPublisher
            .map(VPNLocationPreferenceItemModel.init(selectedLocation:))
            .assign(to: \.locationItem, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    @MainActor
    func uninstallVPN() async {
        let response = await uninstallVPNConfirmationAlert().runModal()

        switch response {
        case .OK:
            try? await VPNUninstaller().uninstall(removeSystemExtension: true)
        default:
            // intentional no-op
            break
        }
    }

    @MainActor
    func uninstallVPNConfirmationAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.uninstallVPNAlertTitle
        alert.informativeText = UserText.uninstallVPNInformativeText
        let uninstallButton = alert.addButton(withTitle: UserText.uninstall)
        uninstallButton.tag = NSApplication.ModalResponse.OK.rawValue
        uninstallButton.keyEquivalent = ""

        let cancelButton = alert.addButton(withTitle: UserText.cancel)
        cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue
        cancelButton.keyEquivalent = "\r"

        return alert
    }
}
