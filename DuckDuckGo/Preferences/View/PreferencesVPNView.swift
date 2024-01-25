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

#if NETWORK_PROTECTION

import PreferencesViews
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct VPNView: View {
        @ObservedObject var model: VPNPreferencesModel

        var body: some View {
            PreferencePane(UserText.vpn) {

                if model.shouldShowLocationItem {
                    PreferencePaneSection(UserText.vpnLocationTitle) {
                        VPNLocationPreferenceItem(model: model.locationItem)
                    }
                }

                // SECTION: Manage VPN

                PreferencePaneSection(UserText.vpnGeneralTitle) {

                    SpacedCheckbox {
                        ToggleMenuItem(UserText.vpnConnectOnLoginSettingTitle, isOn: $model.connectOnLogin)
                    }

                    SpacedCheckbox {
                        ToggleMenuItem(UserText.vpnShowInMenuBarSettingTitle, isOn: $model.showInMenuBar)
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
                            Image("InfoSubtle-16")

                            VStack {
                                HStack {
                                    Text(UserText.vpnSecureDNSSettingDescription)
                                        .padding(0)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color("BlackWhite60"))
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
                        .background(Color("BlackWhite1"))
                        .roundedBorder()
                }

                // SECTION: VPN Notifications

                PreferencePaneSection(UserText.vpnNotificationsSettingsTitle) {

                    ToggleMenuItem("VPN connection drops or status changes", isOn: $model.notifyStatusChanges)
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

#endif
