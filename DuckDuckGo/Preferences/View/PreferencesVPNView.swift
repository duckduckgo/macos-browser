//
//  PreferencesVPNView.swift
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

import NetworkProtection
import PixelKit
import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct VPNView: View {
        @ObservedObject var model: VPNPreferencesModel
        @ObservedObject var status: PrivacyProtectionStatus
        @State private var showsCustomDNSServerPageSheet = false

        var body: some View {
            PreferencePane(UserText.vpn, spacing: 4) {

                if let status = status.status {
                    PreferencePaneSection {
                        StatusIndicatorView(status: status, isLarge: true)
                    }
                }

                PreferencePaneSection {
                    Button(UserText.openVPNButtonTitle) {
                        Task { @MainActor in
                            NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: nil)
                        }
                    }
                }
                .padding(.bottom, 12)

                // SECTION: Location

                PreferencePaneSection {
                    TextMenuItemHeader(UserText.vpnLocationTitle)
                    VPNLocationPreferenceItem(model: model.locationItem)
                }
                .padding(.bottom, 12)

                if model.showLegacyExclusionsFeature {
                    // SECTION: Excluded Sites

                    PreferencePaneSection(UserText.vpnExcludedSitesTitle, spacing: 4) {
                        Text(UserText.vpnExcludedDomainsDescription)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 18)

                        PreferencePaneSubSection {
                            Button(UserText.vpnExcludedDomainsManageButtonTitle) {
                                model.manageExcludedSites()
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }

                // SECTION: General

                PreferencePaneSection(UserText.vpnGeneralTitle) {

                    SpacedCheckbox {
                        ToggleMenuItem(UserText.vpnConnectOnLoginSettingTitle, isOn: $model.connectOnLogin)
                    }

                    SpacedCheckbox {
                        ToggleMenuItemWithDescription(
                            UserText.vpnExcludeLocalNetworksSettingTitle,
                            UserText.vpnExcludeLocalNetworksSettingDescription,
                            isOn: $model.excludeLocalNetworks,
                            spacing: 12
                        )
                    }
                }
                .padding(.bottom, 12)

                // SECTION: Shortcuts

                PreferencePaneSection(UserText.vpnShortcutsSettingsTitle) {
                    SpacedCheckbox {
                        ToggleMenuItem(UserText.vpnShowInMenuBarSettingTitle, isOn: $model.showInMenuBar)
                    }

                    SpacedCheckbox {
                        ToggleMenuItem(UserText.vpnShowInBrowserToolbarSettingTitle, isOn: $model.showInBrowserToolbar)
                    }
                }
                .padding(.bottom, 12)

                // SECTION: VPN Notifications

                PreferencePaneSection(UserText.vpnNotificationsSettingsTitle) {
                    ToggleMenuItem(UserText.vpnNotificationsConnectionDropsOrStatusChangesTitle,
                                   isOn: $model.notifyStatusChanges)
                }
                .padding(.bottom, 12)

                if model.showNewExclusionsFeature {
                    // SECTION: Exclusions

                    PreferencePaneSection {
                        TextMenuItemHeader(UserText.vpnExclusionsTitle)
                        TextMenuItemCaption(UserText.vpnSettingsExclusionsDescription)

                        SubfeatureGroup {
                            SubfeatureView(icon: Image(.globe16),
                                           title: UserText.vpnExcludedSitesTitle,
                                           description: exclusionCountString(value: model.excludedDomainsCount),
                                           buttonName: UserText.vpnSettingsManageExclusionsButtonTitle,
                                           buttonAction: { model.manageExcludedSites() },
                                           enabled: true)

                            Divider()
                                .foregroundColor(Color.secondary)

                            SubfeatureView(icon: Image(.window16),
                                           title: UserText.vpnExcludedAppsTitle,
                                           description: exclusionCountString(value: model.excludedAppsCount),
                                           buttonName: UserText.vpnSettingsManageExclusionsButtonTitle,
                                           buttonAction: { model.manageExcludedApps() },
                                           enabled: true)
                        }
                    }
                    .padding(.bottom, 12)
                }

                // SECTION: DNS Settings

                PreferencePaneSection(UserText.vpnDnsServerTitle) {
                    PreferencePaneSubSection {
                        Picker(selection: $model.isCustomDNSSelected, label: EmptyView()) {
                            Text(UserText.vpnDnsServerPickerDefaultTitle).tag(false)
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 15) {
                                    Text(UserText.vpnDnsServerPickerCustomTitle)
                                    Button(UserText.vpnDnsServerPickerCustomButtonTitle) {
                                        showsCustomDNSServerPageSheet.toggle()
                                    }.disabled(!model.isCustomDNSSelected)
                                }
                                if let dnsServersText = model.dnsSettings.dnsServersText {
                                    TextMenuItemCaption(dnsServersText)
                                        .padding(.top, 0)
                                        .visibility(model.isCustomDNSSelected ? .visible : .gone)
                                }
                            }.tag(true)
                        }
                        .pickerStyle(.radioGroup)
                        .offset(x: PreferencesUI_macOS.Const.pickerHorizontalOffset)
                        .onChange(of: model.isCustomDNSSelected) { isCustomDNSSelected in
                            if isCustomDNSSelected {
                                showsCustomDNSServerPageSheet.toggle()
                            } else {
                                model.resetDNSSettings()
                                PixelKit.fire(NetworkProtectionPixelEvent.networkProtectionDNSUpdateDefault, frequency: .legacyDailyAndCount)
                            }
                        }
                        .onChange(of: showsCustomDNSServerPageSheet) { showsCustomDNSServerPageSheet in
                            guard !showsCustomDNSServerPageSheet else { return }
                            /// Flip the setting back if no DNS server is defined
                            if model.isCustomDNSSelected, !model.dnsSettings.usesCustomDNS {
                                model.isCustomDNSSelected = false
                            }
                        }

                        if model.isCustomDNSSelected {
                            TextMenuItemCaption(UserText.vpnDnsServerIPv4Disclaimer)
                        } else {
                            TextMenuItemCaption(UserText.vpnSecureDNSSettingDescription)
                        }
                    }
                }.sheet(isPresented: $showsCustomDNSServerPageSheet) {
                    CustomDNSServerPageSheet(settings: VPNSettings(defaults: .netP),
                                             isSheetPresented: $showsCustomDNSServerPageSheet)
                }

                // SECTION: Uninstall

                if model.showUninstallVPN {
                    PreferencePaneSection {
                        Button(UserText.uninstallVPNButtonTitle) {
                            Task { @MainActor in
                                await model.uninstallVPN()
                            }
                        }
                    }
                }
            }
        }

        /// Resolves the text to be used for exclusion counts
        ///
        private func exclusionCountString(value: Int) -> String {
            value > 0 ? String(value) : UserText.vpnNoExclusionsFoundText
        }
    }
}

struct CustomDNSServerPageSheet: View {
    private let settings: VPNSettings

    @State var customDNSServers = ""
    @State var isValidDNSServers = true
    @Binding var isSheetPresented: Bool

    init(settings: VPNSettings, isSheetPresented: Binding<Bool>) {
        self.settings = settings
        self._isSheetPresented = isSheetPresented
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(UserText.vpnDnsServerSheetTitle)
                .fontWeight(.bold)

            Divider()

            Group {
                HStack {
                    Text(UserText.vpnDnsServerIPv4Description)
                        .padding(.trailing, 10)
                    Spacer()
                    TextField("0.0.0.0", text: $customDNSServers)
                        .frame(width: 250)
                        .onChange(of: customDNSServers) { newValue in
                            validateDNSServers(newValue)
                        }
                }
                Text(UserText.vpnDnsServerIPv4Disclaimer)
                    .multilineText()
                    .multilineTextAlignment(.leading)
                    .fixMultilineScrollableText()
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(alignment: .center) {
                Spacer()
                Button(UserText.cancel) {
                    isSheetPresented.toggle()
                }
                Button(UserText.vpnDnsServerApplyButtonTitle) {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidDNSServers)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .frame(width: 400)
        .onAppear {
            customDNSServers = settings.dnsSettings.dnsServersText ?? ""
        }
    }

    private func saveChanges() {
        settings.dnsSettings = .custom([customDNSServers])
        isSheetPresented.toggle()

        /// Updating `dnsSettings` does an IPv4 conversion before actually commiting the change,
        /// so we do a final check to see which outcome the user ends up with
        if settings.dnsSettings.usesCustomDNS {
            PixelKit.fire(NetworkProtectionPixelEvent.networkProtectionDNSUpdateCustom, frequency: .legacyDailyAndCount)
        } else {
            PixelKit.fire(NetworkProtectionPixelEvent.networkProtectionDNSUpdateDefault, frequency: .legacyDailyAndCount)
        }
    }

    private func validateDNSServers(_ text: String) {
        isValidDNSServers = !text.isEmpty && text.isValidIpv4Host
    }
}
