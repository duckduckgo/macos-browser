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

extension Preferences {

    struct VPNView: View {
        @ObservedObject var model: VPNPreferencesModel
        @ObservedObject var status: PrivacyProtectionStatus

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
