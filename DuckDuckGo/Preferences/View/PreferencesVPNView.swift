//
//  PreferencesPrivacyView.swift
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

import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct VPNView: View {
        @ObservedObject var model: VPNPreferencesModel

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {

                // TITLE

                TextMenuTitle(text: UserText.vpn)

                // SECTION: Manage VPN

                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.vpnGeneralTitle)

                    SpacedCheckbox {
                        ToggleMenuItem(title: UserText.vpnConnectOnLoginSettingTitle, isOn: $model.connectOnLogin)
                    }

                    SpacedCheckbox {
                        ToggleMenuItem(title: UserText.vpnShowInMenuBarSettingTitle, isOn: $model.showInMenuBar)
                    }

                    SpacedCheckbox {
                        ToggleMenuItemWithDescription(title: UserText.vpnExcludeLocalNetworksSettingTitle,
                                                      description: UserText.vpnExcludeLocalNetworksSettingDescription,
                                                      isOn: $model.excludeLocalNetworks,
                                                      spacing: 12)
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
                        .background(Color("BlackWhite10"))
                        .roundedBorder()
                }

                // SECTION: VPN Notifications

                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.vpnNotificationsSettingsTitle)

                    ToggleMenuItem(title: "VPN connection drops or status changes", isOn: $model.notifyStatusChanges)
                }

                // SECTION: Uninstall

                if model.showUninstallVPN {
                    PreferencePaneSection {
                        Button(UserText.uninstallVPNButtonTitle) {
                            model.uninstallVPN()
                        }
                    }
                }
            }
        }
    }
}
