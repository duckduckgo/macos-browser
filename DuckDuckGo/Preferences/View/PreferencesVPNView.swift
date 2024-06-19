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

import PreferencesViews
import SwiftUI
import SwiftUIExtensions
import NetworkProtection

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

                // SECTION: Manage VPN

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

                    VStack(alignment: .leading) {
                        HStack(spacing: 10) {
                            Image(.infoSubtle16)

                            VStack {
                                HStack {
                                    Text(UserText.vpnSecureDNSSettingDescription)
                                        .padding(0)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(.blackWhite60))
                                        .multilineTextAlignment(.leading)
                                        .fixMultilineScrollableText()

                                    Spacer()
                                }
                            }
                            .frame(idealWidth: .infinity, maxWidth: .infinity)

                            Spacer()
                        }
                    }.frame(alignment: .topLeading)
                        .frame(idealWidth: .infinity, maxWidth: .infinity)
                        .padding(10)
                        .background(Color(.blackWhite1))
                        .roundedBorder()
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
                    ToggleMenuItem("VPN connection drops or status changes", isOn: $model.notifyStatusChanges)
                }
                .padding(.bottom, 12)

                // SECTION: DNS Settings

                PreferencePaneSection("DNS Server") {
                    PreferencePaneSubSection {
                        Picker(selection: $model.isCustomDNSSelected, label: EmptyView()) {
                            Text("DuckDuckGo (Recommended)").tag(false)
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 15) {
                                    Text("Custom")
                                    Button("Set DNS Server...") {
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
                        .offset(x: PreferencesViews.Const.pickerHorizontalOffset)
                        .onChange(of: model.isCustomDNSSelected) { isCustomDNSSelected in
                            guard !isCustomDNSSelected else { return }
                            model.resetDNSSettings()
                        }

                        TextMenuItemCaption("DuckDuckGo routes DNS queries through our DNS servers so your internet provider can't see what websites you visit.")

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
            Text("Custom DNS Server")
                .fontWeight(.bold)

            Divider()

            Group {
                HStack {
                    Text("IPv4 Address:")
                        .padding(.trailing, 10)
                    Spacer()
                    TextField("0.0.0.0", text: $customDNSServers)
                        .frame(width: 250)
                        .onChange(of: customDNSServers) { newValue in
                            validateDNSServers(newValue)
                        }
                }
                Text("Using a custom DNS server can impact browsing speeds and expose your activity to third parties if the server isn't secure or reliable.")
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
                Button("Apply") {
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
    }

    private func validateDNSServers(_ text: String) {
        isValidDNSServers = !text.isEmpty && text.isValidIpv4Host
    }
}
