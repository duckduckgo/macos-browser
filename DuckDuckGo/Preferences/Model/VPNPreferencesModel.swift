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
import NetworkProtectionIPC
import NetworkProtectionProxy
import NetworkProtectionUI
import BrowserServicesKit

final class VPNPreferencesModel: ObservableObject {

    @Published var locationItem: VPNLocationPreferenceItemModel

    @Published var alwaysON = true

    @Published var connectOnLogin: Bool {
        didSet {
            guard settings.connectOnLogin != connectOnLogin else {
                return
            }

            settings.connectOnLogin = connectOnLogin
        }
    }

    @Published var excludeLocalNetworks: Bool {
        didSet {
            guard settings.excludeLocalNetworks != excludeLocalNetworks else {
                return
            }

            settings.excludeLocalNetworks = excludeLocalNetworks

            Task {
                // We need to allow some time for the setting to propagate
                // But ultimately this should actually be a user choice
                try await Task.sleep(interval: 0.1)
                try await vpnXPCClient.command(.restartAdapter)
            }
        }
    }

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


    var appExclusionsFeatureEnabled: Bool {
        featureFlagger.isFeatureOn(.networkProtectionAppExclusions)
    }

    /// Whether the excluded sites section in preferences is shown.
    ///
    /// Only necessary because this is feature flagged to internal users.
    ///
    var showExcludedSites: Bool {
        proxySettings.proxyAvailable
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

    @Published public var dnsSettings: NetworkProtectionDNSSettings = .default
    @Published public var isCustomDNSSelected = false
    @Published public var customDNSServers: String?

    private let vpnXPCClient: VPNControllerXPCClient
    private let settings: VPNSettings
    private let proxySettings: TransparentProxySettings
    private let pinningManager: PinningManager
    private let featureFlagger: FeatureFlagger
    private var cancellables = Set<AnyCancellable>()

    init(vpnXPCClient: VPNControllerXPCClient = .shared,
         settings: VPNSettings = .init(defaults: .netP),
         proxySettings: TransparentProxySettings = .init(defaults: .netP),
         pinningManager: PinningManager = LocalPinningManager.shared,
         defaults: UserDefaults = .netP,
         featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger) {

        self.vpnXPCClient = vpnXPCClient
        self.settings = settings
        self.proxySettings = proxySettings
        self.pinningManager = pinningManager
        self.featureFlagger = featureFlagger

        connectOnLogin = settings.connectOnLogin
        excludeLocalNetworks = settings.excludeLocalNetworks
        notifyStatusChanges = settings.notifyStatusChanges
        showInMenuBar = settings.showInMenuBar
        showInBrowserToolbar = pinningManager.isPinned(.networkProtection)
        showUninstallVPN = defaults.networkProtectionOnboardingStatus != .default
        onboardingStatus = defaults.networkProtectionOnboardingStatus
        locationItem = VPNLocationPreferenceItemModel(selectedLocation: settings.selectedLocation)

        subscribeToOnboardingStatusChanges(defaults: defaults)
        subscribeToConnectOnLoginSettingChanges()
        subscribeToExcludeLocalNetworksSettingChanges()
        subscribeToShowInMenuBarSettingChanges()
        subscribeToShowInBrowserToolbarSettingsChanges()
        subscribeToLocationSettingChanges()
        subscribeToDNSSettingsChanges()
    }

    func subscribeToOnboardingStatusChanges(defaults: UserDefaults) {
        defaults.networkProtectionOnboardingStatusPublisher
            .assign(to: \.onboardingStatus, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    func subscribeToConnectOnLoginSettingChanges() {
        settings.connectOnLoginPublisher
            .assign(to: \.connectOnLogin, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    func subscribeToExcludeLocalNetworksSettingChanges() {
        settings.excludeLocalNetworksPublisher
            .assign(to: \.excludeLocalNetworks, onWeaklyHeld: self)
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

    func subscribeToDNSSettingsChanges() {
        settings.dnsSettingsPublisher
            .assign(to: \.dnsSettings, onWeaklyHeld: self)
            .store(in: &cancellables)
        isCustomDNSSelected = settings.dnsSettings.usesCustomDNS
        customDNSServers = settings.dnsSettings.dnsServersText
    }

    func resetDNSSettings() {
        settings.dnsSettings = .default
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

    // MARK: - Excluded Sites

    @MainActor
    func manageExcludedSites() {
        let windowController = ExcludedDomainsViewController.create().wrappedInWindowController()

        guard let window = windowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("DataClearingPreferences: Failed to present ExcludedDomainsViewController")
            return
        }

        parentWindowController.window?.beginSheet(window)
    }
}

extension NetworkProtectionDNSSettings {
    var dnsServersText: String? {
        switch self {
        case .default: return nil
        case .custom(let servers): return servers.joined(separator: ", ")
        }
    }
}
