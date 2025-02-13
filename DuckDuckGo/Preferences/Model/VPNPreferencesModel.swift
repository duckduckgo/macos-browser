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
import BrowserServicesKit
import Combine
import Foundation
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionProxy
import NetworkProtectionUI
import PixelKit

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

    private var isAppExclusionsFeatureEnabled: Bool {
        featureFlagger.isFeatureOn(.networkProtectionAppExclusions)
    }

    var isRiskySitesProtectionFeatureEnabled: Bool {
        featureFlagger.isFeatureOn(.networkProtectionRickyDomainsProtection)
    }

    private var isExclusionsFeatureAvailableInBuild: Bool {
        proxySettings.proxyAvailable
    }

    /// Whether legacy app exclusions should be shown
    ///
    var showLegacyExclusionsFeature: Bool {
        isExclusionsFeatureAvailableInBuild && !isAppExclusionsFeatureEnabled
    }

    /// Whether new app exclusions should be shown
    ///
    var showNewExclusionsFeature: Bool {
        isExclusionsFeatureAvailableInBuild && isAppExclusionsFeatureEnabled
    }

    @Published
    private(set) var excludedDomainsCount: Int

    @Published
    private(set) var excludedAppsCount: Int

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

    @Published public var dnsSettings: NetworkProtectionDNSSettings
    @Published public var isCustomDNSSelected = false
    @Published public var customDNSServers: String?
    @Published var isBlockRiskyDomainsOn: Bool {
        didSet {
            guard settings.isBlockRiskyDomainsOn != isBlockRiskyDomainsOn else { return }
            settings.dnsSettings = .ddg(blockRiskyDomains: isBlockRiskyDomainsOn)
            reloadVPN()
        }
    }

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
        excludedAppsCount = proxySettings.appRoutingRules.filter { (_, rule) in
            rule == .exclude
        }.count
        excludedDomainsCount = proxySettings.excludedDomains.count
        excludeLocalNetworks = settings.excludeLocalNetworks
        notifyStatusChanges = settings.notifyStatusChanges
        showInMenuBar = settings.showInMenuBar
        showInBrowserToolbar = pinningManager.isPinned(.networkProtection)
        showUninstallVPN = defaults.networkProtectionOnboardingStatus != .default
        onboardingStatus = defaults.networkProtectionOnboardingStatus
        locationItem = VPNLocationPreferenceItemModel(selectedLocation: settings.selectedLocation)
        isBlockRiskyDomainsOn = settings.isBlockRiskyDomainsOn
        dnsSettings = settings.dnsSettings

        subscribeToAppRoutingRulesChanges()
        subscribeToOnboardingStatusChanges(defaults: defaults)
        subscribeToConnectOnLoginSettingChanges()
        subscribeToExcludedDomainsCountChanges()
        subscribeToExcludeLocalNetworksSettingChanges()
        subscribeToShowInMenuBarSettingChanges()
        subscribeToShowInBrowserToolbarSettingsChanges()
        subscribeToLocationSettingChanges()
        subscribeToDNSSettingsChanges()
        subscribeToBlockRiskyDomainsChanges()
    }

    private func subscribeToAppRoutingRulesChanges() {
        proxySettings.appRoutingRulesPublisher
            .map { rules in
                rules.filter { (_, rule) in
                    rule == .exclude
                }.count
            }
            .assign(to: \.excludedAppsCount, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToOnboardingStatusChanges(defaults: UserDefaults) {
        defaults.networkProtectionOnboardingStatusPublisher
            .assign(to: \.onboardingStatus, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToConnectOnLoginSettingChanges() {
        settings.connectOnLoginPublisher
            .assign(to: \.connectOnLogin, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToExcludedDomainsCountChanges() {
        proxySettings.excludedDomainsPublisher
            .map { $0.count }
            .assign(to: \.excludedDomainsCount, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToExcludeLocalNetworksSettingChanges() {
        settings.excludeLocalNetworksPublisher
            .assign(to: \.excludeLocalNetworks, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToShowInMenuBarSettingChanges() {
        settings.showInMenuBarPublisher
            .removeDuplicates()
            .assign(to: \.showInMenuBar, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToShowInBrowserToolbarSettingsChanges() {
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

    private func subscribeToLocationSettingChanges() {
        settings.selectedLocationPublisher
            .map(VPNLocationPreferenceItemModel.init(selectedLocation:))
            .assign(to: \.locationItem, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToDNSSettingsChanges() {
        settings.dnsSettingsPublisher
            .assign(to: \.dnsSettings, onWeaklyHeld: self)
            .store(in: &cancellables)
        isCustomDNSSelected = settings.dnsSettings.usesCustomDNS
        customDNSServers = settings.customDnsServers.joined(separator: ", ")
    }

    private func subscribeToBlockRiskyDomainsChanges() {
        settings.isBlockRiskyDomainsOnPublisher
            .map { $0 }
            .assign(to: \.isBlockRiskyDomainsOn, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    func reloadVPN() {
        Task {
            // Allow some time for the change to propagate
            try await Task.sleep(interval: 0.1)

            try await vpnXPCClient.command(.restartAdapter)
        }
    }

    func resetDNSSettings() {
        settings.dnsSettings = .ddg(blockRiskyDomains: settings.isBlockRiskyDomainsOn)
        reloadVPN()
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

    // MARK: - Actions

    @MainActor
    func manageExcludedApps() {
        WindowControllersManager.shared.showVPNAppExclusions()
    }

    @MainActor
    func manageExcludedSites() {
        WindowControllersManager.shared.showVPNDomainExclusions()
    }

    @MainActor
    func openNewTab(with url: URL) {
        WindowControllersManager.shared.show(url: url, source: .ui, newTab: true)
    }

    func saveChanges(customDNSServers: String) {
        self.customDNSServers = customDNSServers
        settings.dnsSettings = .custom([customDNSServers])
        reloadVPN()
        /// Updating dnsSettings does an IPv4 conversion before actually commiting the change,
        /// so we do a final check to see which outcome the user ends up with
        if settings.dnsSettings.usesCustomDNS {
            PixelKit.fire(NetworkProtectionPixelEvent.networkProtectionDNSUpdateCustom, frequency: .legacyDailyAndCount)
        } else {
            PixelKit.fire(NetworkProtectionPixelEvent.networkProtectionDNSUpdateDefault, frequency: .legacyDailyAndCount)
        }
    }
}

extension NetworkProtectionDNSSettings {
    var dnsServersText: String? {
        switch self {
        case .ddg: return ""
        case .custom(let servers): return servers.joined(separator: ", ")
        }
    }
}
